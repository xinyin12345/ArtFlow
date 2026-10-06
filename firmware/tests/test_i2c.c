#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "platform.h"
#include "camera.h"

static uint32_t timer, master, registers[64];
static unsigned bytes[32], count, starts, stops, recoveries, drops, ack_reads;
static int nack_at, no_ack, drop_start, stuck_stop, pending_ack, pending_data, read_mode;

static void reset_model(void) {
    memset(registers, 0, sizeof registers);
    timer = 0xffff0000u; master = 0; /* Every test crosses timer wrap. */
    count = starts = stops = recoveries = drops = ack_reads = 0;
    nack_at = -1; no_ack = drop_start = stuck_stop = pending_ack = pending_data = read_mode = 0;
    i2c_init();
    assert(registers[0x28 / 4] == 3u && registers[0x50 / 4] == 500u);
    assert(registers[0x2c / 4] == 999999u && registers[0x2c / 4] <= 0xfffffu);
    assert(registers[0x30 / 4] == 49u && registers[0x30 / 4] <= 0x3fu);
    assert(registers[0x08 / 4] == 0x200u && registers[0x0c / 4] == 0x200u);
}
uint32_t mmio_read(uint32_t address) {
    if (address == CLINT_MTIME) { timer += 100000u; return timer; }
    assert(address >= I2C_BASE && address < I2C_BASE + 256u);
    unsigned offset = address - I2C_BASE;
    if (offset == 0x40u) return master;
    if (offset == 0x0cu && pending_ack && !no_ack && (registers[offset / 4] & 0x200u)) {
        if (++ack_reads < 3u) return 0; /* Exercise actual polling. */
        pending_ack = 0;
        return 0x100u | (count == (unsigned)(nack_at + 1) ? 1u : 0u);
    }
    if (offset == 0x08u && pending_data && (registers[offset / 4] & 0x200u)) {
        pending_data = 0;
        return 0x15au;
    }
    if (offset == 0x04u) return 0;
    return 0;
}
void mmio_write(uint32_t address, uint32_t value) {
    assert(address >= I2C_BASE && address < I2C_BASE + 256u);
    unsigned offset = address - I2C_BASE;
    registers[(offset / 4) & 63u] = value;
    if (offset == 0x40u) {
        if (value & 0x10u) { ++starts; master = drop_start ? 0x200u : 1u; }
        if (value & 0x20u) { ++stops; master = stuck_stop ? 0x21u : 0u; }
        if (value & 0x40u) { ++drops; master = 0; }
        if (value & (0x20u | 0x40u)) {
            /* Actual Sapphire STOP/DROP clear both receive-listen enables.
             * This must also apply after recovery, not just initial startup. */
            registers[0x08 / 4] = registers[0x0c / 4] = 0;
            pending_ack = pending_data = read_mode = 0;
        }
        if (value & 0x80u) { ++recoveries; master = 0; }
    } else if (offset == 0x00u && (value & 0x100u)) {
        if (read_mode) {
            assert(value == 0x3ffu); /* Slave zeros must not count as collisions. */
        } else {
            assert(count < 32);
            bytes[count++] = value & 0xffu;
            if (value == 0xb61u) read_mode = 1;
        }
    } else if (offset == 0x04u && (value & 0x100u)) {
        assert(value == 0x301u);
        if (registers[0] == 0x3ffu) pending_data = 1;
        else { pending_ack = 1; ack_reads = 0; }
    }
}
int main(void) {
    reset_model();
    assert(camera_write(0x3208u, 7u) == I2C_OK);
    assert(count == 4 && bytes[0] == 0x60 && bytes[1] == 0x32 && bytes[2] == 8 && bytes[3] == 7);
    assert(starts == 1 && stops == 1 && recoveries == 0);
    assert(camera_write(0x36e9u, 0x80u) == I2C_OK);
    assert(count == 8 && bytes[4] == 0x60 && bytes[5] == 0x36 && bytes[6] == 0xe9 && bytes[7] == 0x80);
    assert(starts == 2 && stops == 2 && recoveries == 0);
    for (int i = 0; i < 4; ++i) {
        reset_model(); nack_at = i;
        assert(camera_write(0x3208u, 7u) == I2C_NACK_ERROR);
        assert(count == (unsigned)i + 1 && recoveries == 1 && drops == 2 && stops == 1);
        nack_at = -1;
        assert(camera_write(0x3208u, 7u) == I2C_OK); /* Rearm after recovery. */
    }
    reset_model(); no_ack = 1;
    assert(camera_write(0x3208u, 7u) == I2C_TIMEOUT_ERROR && recoveries == 1);
    reset_model(); drop_start = 1;
    assert(camera_write(0x3208u, 7u) == I2C_BUS_ERROR && count == 0 && recoveries == 1);
    reset_model(); stuck_stop = 1;
    assert(camera_write(0x3208u, 7u) == I2C_TIMEOUT_ERROR && recoveries == 1);
    reset_model();
    uint8_t readback = 0;
    assert(camera_read(0x3208u, &readback) == I2C_OK && readback == 0x5a);
    assert(starts == 2 && stops == 1 && count == 4 && bytes[3] == 0x61);
    assert(camera_read(0x3209u, &readback) == I2C_OK && readback == 0x5a);
    assert(starts == 4 && stops == 2 && count == 8 && bytes[7] == 0x61);
    puts("PASS I2C: write/read wire bytes, consecutive STOP-separated transactions, LISTEN rearm after recovery, repeated START, per-byte NACK, ACK timeout, dropped START, stuck STOP, timer wrap, bounded recovery, hardware timing widths");
}
