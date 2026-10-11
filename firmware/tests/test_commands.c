#include <assert.h>
#include <stdio.h>
#include <string.h>
#define main firmware_main
#include "../src/main.c"
#undef main

static uint32_t timer, control[32], write_offsets[16], write_values[16];
static unsigned write_count, text_used, polls;
static int complete_commit;
static unsigned init_calls, init_profile, timing_calls;
static enum i2c_result timing_error;
static char text[2048];
static uint32_t rx_error;
static const char *rx_input;
static int error_on_last_char;
static void reset_model(void) {
    memset(control, 0, sizeof control);
    timer = 0xffff0000u;
    write_count = text_used = polls = 0;
    init_calls = timing_calls = 0; timing_error = I2C_OK;
    complete_commit = 1; text[0] = 0; control_valid = 1;
    rx_error = 0; rx_input = ""; error_on_last_char = 0;
}
uint32_t mmio_read(uint32_t address) {
    if (address == CLINT_MTIME) { timer += 1000000u; return timer; }
    if (address == UART_BASE + 4u) return 0x00ff0000u | (*rx_input ? 0x01000000u : 0);
    if (address == UART_BASE + 0x10u) return rx_error;
    if (address == UART_BASE) {
        uint8_t value = (uint8_t)*rx_input++;
        if (error_on_last_char && value == '\r') rx_error = 1;
        return value;
    }
    assert(address >= CONTROL_BASE && address < CONTROL_BASE + 128u);
    unsigned offset = address - CONTROL_BASE;
    if (offset == REG_STATUS && (control[REG_STATUS / 4] & STATUS_BUSY) && complete_commit && ++polls > 3u) {
        control[REG_STATUS / 4] = 0;
        for (unsigned i = 0; i < 3; ++i) control[REG_ACTIVE_R / 4 + i] = control[REG_SHADOW_R / 4 + i];
    }
    return control[offset / 4];
}
void mmio_write(uint32_t address, uint32_t value) {
    if (address == UART_BASE) {
        assert(text_used < sizeof text - 1);
        text[text_used++] = (char)value; text[text_used] = 0; return;
    }
    if (address == UART_BASE + 0x10u) { rx_error &= ~value; return; }
    if (address > UART_BASE && address < UART_BASE + 16u) return;
    assert(address >= CONTROL_BASE && address < CONTROL_BASE + 64u && write_count < 16u);
    unsigned offset = address - CONTROL_BASE;
    write_offsets[write_count] = offset; write_values[write_count++] = value;
    control[(offset / 4) & 15u] = value;
    if (offset == REG_COMMIT) control[REG_STATUS / 4] = STATUS_BUSY;
}
struct camera_result camera_configure(unsigned baseline) {
    ++init_calls; init_profile = baseline; control[REG_CAMERA / 4] = CAMERA_READY;
    struct camera_result result = {I2C_OK, 0, 0}; return result;
}
struct camera_result camera_get_timing(struct camera_timing *timing) {
    ++timing_calls;
    *timing = (struct camera_timing){3000,1500,2989};
    return (struct camera_result){timing_error,0x320e,2};
}
static void command(const char *line) {
    struct command parsed = parse_command(line); execute(&parsed);
}
int main(void) {
    reset_model();
    control[0x38 / 4] = 123; control[0x3c / 4] = 456; control[0x40 / 4] = 789;
    control[0x44 / 4] = 25; control[0x48 / 4] = 3200; control[0x4c / 4] = 24;
    control[0x50 / 4] = 0x20284; control[0x54 / 4] = 0x100080;
    control[0x58 / 4] = 128; control[0x5c / 4] = 256;
    control[0x60 / 4] = 10; control[0x64 / 4] = 2;
    command("status");
    assert(write_count == 0);
    assert(strstr(text, "diag_v1 vs_edges=123 raw256=456 bin256=789") != NULL);
    assert(strstr(text, "axi_aw=25 w=3200 b=24") != NULL);
    assert(strstr(text, "video_state=0x00020284 fifo_beats=0x00100080") != NULL);
    assert(strstr(text, "written=128 completed=256 published=10 rejected=2") != NULL);
    reset_model(); command("wb 1024 0 256");
    assert(write_count == 4 && write_offsets[0] == 0x10 && write_values[0] == 1024);
    assert(write_offsets[1] == 0x14 && write_values[1] == 0);
    assert(write_offsets[2] == 0x18 && write_values[2] == 256);
    assert(write_offsets[3] == 0x1c && write_values[3] == 1);
    assert(strstr(text, "OK wb applied") != NULL);
    reset_model(); complete_commit = 0; command("wb 1 2 3");
    assert(write_count == 4 && strstr(text, "PENDING wb") != NULL);
    assert(strstr(text, "OK wb applied") == NULL);
    command("wb 4 5 6");
    assert(write_count == 4 && strstr(text, "ERR wb busy") != NULL);
    reset_model(); command("defaults");
    assert(write_values[0] == DEFAULT_R && write_values[1] == DEFAULT_G && write_values[2] == DEFAULT_B);
    reset_model(); command("help");
    assert(strstr(text, "defaults 102 102 102") != NULL);
    reset_model(); command("wb 1 2 3 extra");
    assert(write_count == 0 && strstr(text, "ERR syntax") != NULL);
    reset_model(); control_valid = 0; command("wb 1 2 3");
    assert(write_count == 0 && strstr(text, "ID mismatch") != NULL);
    reset_model(); command("cam off");
    assert(write_count == 1 && write_offsets[0] == REG_CAMERA && write_values[0] == CAMERA_RESET);
    reset_model(); command("cam init");
    assert(init_calls == 1 && init_profile == 0 && timing_calls == 1);
    assert(strstr(text,"P1 VTS1500 EXP2989") != NULL);
    assert(strstr(text,"cam_timing hts=3000 vts=1500 exposure_half_lines=2989") != NULL);
    reset_model(); command("cam baseline");
    assert(init_calls == 1 && init_profile == 1 && strstr(text,"BASELINE") != NULL);
    reset_model(); control[REG_CAMERA / 4] = CAMERA_READY; command("cam timing");
    assert(init_calls == 0 && timing_calls == 1 && write_count == 0);
    reset_model(); command("cam timing");
    assert(timing_calls == 0 && write_count == 0 && strstr(text,"ERR camera off") != NULL);
    reset_model(); control[REG_CAMERA / 4] = CAMERA_READY; timing_error = I2C_TIMEOUT_ERROR;
    command("cam timing");
    assert(strstr(text,"ERR timing TIMEOUT reg=0x0000320e") != NULL);
    assert(strstr(text,"cam_timing") == NULL && write_count == 0);
    reset_model(); control_valid = 0; command("cam baseline"); command("cam timing");
    assert(init_calls == 0 && timing_calls == 0 && write_count == 0);
    for (unsigned error = 1; error <= 0x200u; error <<= 1) {
        if (!(error & 0x203u)) continue;
        reset_model();
        struct line_reader reader = { {0}, 0, 0 };
        rx_input = "wb 280 255 350\r";
        poll_console(&reader); poll_console(&reader);
        rx_error = error;
        while (*rx_input) poll_console(&reader);
        assert(write_count == 0 && strstr(text, "ERR line rejected") != NULL && rx_error == 0);
        rx_input = "wb 280 255 350\r";
        while (*rx_input) poll_console(&reader);
        assert(write_count == 4 && strstr(text, "OK wb applied") != NULL);
    }
    reset_model();
    struct line_reader reader = { {0}, 0, 0 };
    error_on_last_char = 1;
    rx_input = "wb 280 255 350\r";
    while (*rx_input) poll_console(&reader);
    assert(write_count == 0 && strstr(text, "ERR line rejected") != NULL);
    puts("PASS command dispatch: atomic RGB order, busy rejection, applied versus pending, defaults, malformed no-write, bad-ID no-write, camera reset, UART framing/overflow/break discard and recovery");
}
