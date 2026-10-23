#include "platform.h"
#include "console.h"
#include "camera.h"

static struct camera_result last_camera;
static uint32_t uart_dropped;
static uint32_t uart_rx_errors;
static int control_valid;
/* Retained symbols are also useful when inspecting a stopped CPU over JTAG. */
volatile uint32_t trap_cause, trap_pc, trap_value;

static void putc_uart(char c) {
    uint32_t start = ticks();
    while (!(mmio_read(UART_BASE + 4u) & 0x00ff0000u)) {
        if (elapsed(start, CORE_HZ / 100u)) { ++uart_dropped; return; }
    }
    mmio_write(UART_BASE, (uint8_t)c);
}
static void print(const char *text) { while (*text) putc_uart(*text++); }
static void decimal(uint32_t n) {
    char buffer[10];
    unsigned used = 0;
    do { buffer[used++] = (char)('0' + n % 10u); n /= 10u; } while (n);
    while (used) putc_uart(buffer[--used]);
}
static void hex(uint32_t n) {
    print("0x");
    for (int shift = 28; shift >= 0; shift -= 4)
        putc_uart("0123456789abcdef"[(n >> shift) & 15u]);
}
static void show_rgb(uint32_t offset) {
    decimal(control_read(offset)); putc_uart(' ');
    decimal(control_read(offset + 4u)); putc_uart(' ');
    decimal(control_read(offset + 8u));
}
static const char *camera_error(enum i2c_result error) {
    switch (error) {
    case I2C_OK: return "OK";
    case I2C_TIMEOUT_ERROR: return "TIMEOUT";
    case I2C_NACK_ERROR: return "NACK";
    case I2C_BUS_ERROR: return "BUS";
    case CAMERA_VERIFY_ERROR: return "READBACK";
    default: return "UNKNOWN";
    }
}
static void show_camera_timing(void) {
    struct camera_timing timing;
    if (!(control_read(REG_CAMERA) & CAMERA_READY)) { print("ERR camera off\r\n"); return; }
    struct camera_result result = camera_get_timing(&timing);
    if (result.code != I2C_OK) {
        print("ERR timing "); print(camera_error(result.code));
        print(" reg="); hex(result.reg); print("\r\n"); return;
    }
    print("cam_timing hts="); decimal(timing.hts);
    print(" vts="); decimal(timing.vts);
    print(" exposure_half_lines="); decimal(timing.exposure_half_lines);
    print("\r\n");
}
static void init_camera(void) {
    print("BUSY camera init\r\n");
    last_camera = camera_configure();
    if (last_camera.code == I2C_OK) {
        print("OK camera P1 VTS1500 EXP2989\r\n");
        show_camera_timing();
    } else {
        print("ERR camera "); print(camera_error(last_camera.code));
        print(" index="); decimal(last_camera.index);
        print(" reg="); hex(last_camera.reg);
        print("; reset; use cam init\r\n");
    }
}
static void apply_gains(uint16_t r, uint16_t g, uint16_t b) {
    if (control_read(REG_STATUS) & STATUS_BUSY) {
        print("ERR wb busy; commit pending\r\n"); return;
    }
    control_write(REG_SHADOW_R, r);
    control_write(REG_SHADOW_G, g);
    control_write(REG_SHADOW_B, b);
    control_write(REG_COMMIT, 1u);
    uint32_t start = ticks();
    while (control_read(REG_STATUS) & STATUS_BUSY) {
        if (elapsed(start, CORE_HZ / 4u)) {
            print("PENDING wb; no frame acknowledgement\r\n"); return;
        }
    }
    /* The hardware active mirror only advances with the pixel-domain ACK. */
    if (control_read(REG_ACTIVE_R) == r && control_read(REG_ACTIVE_G) == g &&
        control_read(REG_ACTIVE_B) == b) print("OK wb applied\r\n");
    else print("ERR wb active mirror mismatch\r\n");
}
static volatile uint32_t accel_irqs;
static void show_video_diagnostics(void) {
    /* In register order: VS, RAW256, BIN256, AW, W, B, STATE, FIFO,
       WRITTEN, COMPLETE, PUBLISHED, REJECTED. Documented in v07_notes. */
    print("diag_v2[38..64]=");
    for (uint32_t reg = 0x38u; reg <= 0x64u; reg += 4u) {
        hex(control_read(reg)); putc_uart(' ');
    }
    print("\r\naccel done/skip/error/cycles=");
    for (uint32_t reg = REG_ACCEL_DONE; reg <= REG_ACCEL_CYCLES; reg += 4u) {
        decimal(control_read(reg)); putc_uart(' ');
    }
    print("irq="); decimal(accel_irqs);
    print(" state="); hex(control_read(REG_ACCEL_STATUS));
    print("\r\n");
}
static void execute(const struct command *command) {
    if (command->kind == CMD_EMPTY) return;
    if (command->kind == CMD_HELP) {
        print("help | status | wb R G B | defaults | cam init/off/timing\r\n"
              "Gains: unsigned decimal 0..1024 Q8.8 (256=1x); defaults ");
        decimal(DEFAULT_R); print(" "); decimal(DEFAULT_G); print(" "); decimal(DEFAULT_B);
        print("\r\nCR/LF; max 63 chars; wait for response\r\n");
        return;
    }
    if (command->kind == CMD_INVALID) {
        print("ERR syntax; help lists commands\r\n"); return;
    }
    if (!control_valid) { print("ERR control ID mismatch\r\n"); return; }
    switch (command->kind) {
    case CMD_STATUS:
        print("status="); hex(control_read(REG_STATUS));
        print(" camera="); hex(control_read(REG_CAMERA));
        print("\r\nactive="); show_rgb(REG_ACTIVE_R);
        print(" shadow="); show_rgb(REG_SHADOW_R);
        print("\r\nlast_camera="); print(camera_error(last_camera.code));
        print(" uart_tx_dropped="); decimal(uart_dropped);
        print(" uart_rx_errors="); decimal(uart_rx_errors);
        print("\r\n"); show_video_diagnostics(); break;
    case CMD_WB: apply_gains(command->rgb[0], command->rgb[1], command->rgb[2]); break;
    case CMD_DEFAULTS: apply_gains(DEFAULT_R, DEFAULT_G, DEFAULT_B); break;
    case CMD_CAM_INIT: init_camera(); break;
    case CMD_CAM_TIMING: show_camera_timing(); break;
    case CMD_CAM_OFF:
        control_write(REG_CAMERA, CAMERA_RESET);
        print("OK camera held reset\r\n"); break;
    default: break;
    }
}
static void check_rx_error(struct line_reader *reader) {
    /* Generated Sapphire UART misc offset 0x10: bit0 framing error, bit1
     * FIFO overflow, bit9 break-detected. All three are write-one-to-clear.
     * A lost byte must never turn a malformed command into a valid command. */
    uint32_t errors = mmio_read(UART_BASE + 0x10u) & 0x203u;
    if (errors) {
        mmio_write(UART_BASE + 0x10u, errors);
        ++uart_rx_errors;
        reader->rejected = 1;
    }
}
static void poll_console(struct line_reader *reader) {
    check_rx_error(reader);
    if (mmio_read(UART_BASE + 4u) >> 24) {
        unsigned char c = (unsigned char)mmio_read(UART_BASE);
        /* Also cover an error arriving between the first misc read and the
         * FIFO pop, particularly a damaged last character/line delimiter. */
        check_rx_error(reader);
        int ready = line_feed(reader, c);
        if (ready > 0) {
            struct command command = parse_command(reader->data);
            execute(&command);
        } else if (ready < 0)
            print("ERR line rejected; RX error, non-ASCII or >63 chars; resend\r\n");
    }
}
void firmware_trap(uint32_t cause, uint32_t pc, uint32_t value) {
    if (cause == 0x8000000bu) {
        uint32_t id;
        while ((id = mmio_read(PLIC_BASE + 0x200004u)) != 0u) {
            if (id == ACCEL_IRQ_ID) {
                control_write(REG_ACCEL_ACK, 1u);
                control_write(REG_ACCEL_CONTROL, 3u);
                ++accel_irqs;
            }
            mmio_write(PLIC_BASE + 0x200004u, id);
        }
        return;
    }
    trap_cause = cause; trap_pc = pc; trap_value = value;
    print("FATAL trap cause="); hex(cause);
    print(" pc="); hex(pc); print(" value="); hex(value); print("\r\n");
    for (;;) { }
}
int main(void) {
    struct line_reader reader = { {0}, 0, 0 };
    mmio_write(UART_BASE + 8u, CORE_HZ / (115200u * 8u) - 1u);
    mmio_write(UART_BASE + 12u, 7u); /* 8 data bits, no parity, one stop. */
    mmio_write(UART_BASE + 4u, 0u); /* Polling; disable TX/RX interrupts. */
    print("\r\nArtFlow v09 S8-CNN CAP-P1; UART 115200 8N1\r\n");
    control_valid = control_read(REG_ID) == CONTROL_ID;
    if (control_valid) init_camera();
    else print("ERR control ID mismatch\r\n");
    if (control_valid && control_read(REG_ACCEL_ID) == 0x41524609u) {
        mmio_write(PLIC_BASE + ACCEL_IRQ_ID * 4u, 1u);
        mmio_write(PLIC_BASE + 0x2000u, 1u << ACCEL_IRQ_ID);
        mmio_write(PLIC_BASE + 0x200000u, 0u);
        control_write(REG_ACCEL_ACK, 1u);
        control_write(REG_ACCEL_CONTROL, 3u);
#ifndef ARTFLOW_HOST_TEST
        __asm__ volatile ("li t0, 0x800; csrs mie, t0; csrsi mstatus, 8" ::: "t0", "memory");
#endif
    }
    print("READY; type help\r\n");
    for (;;) poll_console(&reader);
}
