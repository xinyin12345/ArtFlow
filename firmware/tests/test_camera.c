#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "platform.h"
#include "camera.h"
#include "camera_table.h"

static uint32_t timer, camera_control;
static unsigned writes, reads, ready_count, reset_count, inits, operations, profile;
static int fail_at, mismatch_at;
static uint8_t registers[65536];
struct transaction { uint16_t address; uint8_t value, read; };
static struct transaction trace[200], expected[200];
static void reset_model(unsigned baseline) {
    timer = 0xffff0000u; camera_control = 1; profile = baseline;
    writes = reads = ready_count = reset_count = inits = operations = 0;
    fail_at = mismatch_at = -1;
    memset(registers, 0, sizeof registers);
    registers[0x320e] = 5; registers[0x320f] = 220;
}
uint32_t mmio_read(uint32_t address) {
    assert(address == CLINT_MTIME);
    timer += 1000000u;
    return timer;
}
void mmio_write(uint32_t address, uint32_t value) {
    assert(address == CONTROL_BASE + REG_CAMERA && value <= 2u);
    if (value == CAMERA_RESET) ++reset_count;
    if (value == CAMERA_READY) ++ready_count;
    camera_control = value;
}
void i2c_init(void) { ++inits; }
enum i2c_result camera_write(uint16_t address, uint8_t value) {
    assert(camera_control == 0u && operations < 200);
    trace[operations] = (struct transaction){address, value, 0};
    if (profile) {
        assert(writes < 164 && camera_registers[writes].address == address);
        assert(camera_registers[writes].value == value);
    }
    ++writes;
    if ((int)operations++ == fail_at) return I2C_NACK_ERROR;
    if (!profile && address == 0x0100 && value == 1) {
        /* No P1 stream before full geometry, timing, exposure and readbacks. */
        assert(writes == 166 && reads == 5);
        assert(registers[0x3208] == 7 && registers[0x3209] == 128);
        assert(registers[0x320a] == 4 && registers[0x320b] == 56);
        assert(registers[0x320e] == 5 && registers[0x320f] == 220);
        assert(registers[0x3e00] == 0 && registers[0x3e01] == 186 && registers[0x3e02] == 208);
        assert(registers[0x3221] == 0x66);
    }
    registers[address] = value;
    return I2C_OK;
}
enum i2c_result camera_read(uint16_t address, uint8_t *value) {
    assert(operations < 200);
    trace[operations] = (struct transaction){address, 0, 1};
    ++reads;
    *value = (uint8_t)(registers[address] ^ ((int)operations == mismatch_at));
    return (int)operations++ == fail_at ? I2C_TIMEOUT_ERROR : I2C_OK;
}
int main(void) {
    unsigned faults = 0, mismatches = 0;
    for (unsigned baseline = 0; baseline < 1; ++baseline) {
        reset_model(baseline);
        struct camera_result result = camera_configure();
        assert(result.code == I2C_OK && writes == (baseline ? 164u : 166u));
        assert(reads == (baseline ? 5u : 10u) && ready_count == 1 && inits == 1);
        assert(reset_count == 1 && camera_control == CAMERA_READY);
        unsigned count = operations;
        memcpy(expected, trace, count * sizeof trace[0]);
        if (!baseline) {
            unsigned n = 0;
            for (unsigned i = 0; i < 164; ++i) {
                uint16_t address = camera_registers[i].address;
                uint8_t value = camera_registers[i].value;
                if (address == 0x0100 && value == 1) continue;
                if (address == 0x3e00) value = 0;
                if (address == 0x3e01) value = 0xba;
                if (address == 0x3e02) value = 0xd0;
                assert(!expected[n].read && expected[n].address == address && expected[n].value == value);
                ++n;
            }
            assert(n == 163);
        }
        for (unsigned i = 0; i < count; ++i) {
            reset_model(baseline); fail_at = (int)i;
            result = camera_configure();
            assert(result.code == (expected[i].read ? I2C_TIMEOUT_ERROR : I2C_NACK_ERROR));
            assert(result.index == i && result.reg == expected[i].address && operations == i + 1);
            assert(ready_count == 0 && camera_control == CAMERA_RESET);
            ++faults;
            if (expected[i].read) {
                reset_model(baseline); mismatch_at = (int)i;
                result = camera_configure();
                assert(result.code == CAMERA_VERIFY_ERROR && result.index == i);
                assert(result.reg == expected[i].address && operations == i + 1);
                assert(ready_count == 0 && camera_control == CAMERA_RESET);
                ++mismatches;
            }
        }
    }
    reset_model(0); camera_control = CAMERA_READY;
    registers[0x320c] = 0x12; registers[0x320d] = 0x34;
    registers[0x320e] = 0x85; registers[0x320f] = 0xdc;
    registers[0x3e00] = 0xf1; registers[0x3e01] = 0xbb; registers[0x3e02] = 0xff;
    struct camera_timing timing;
    assert(camera_get_timing(&timing).code == I2C_OK);
    assert(timing.hts == 0x1234 && timing.vts == 1500 && timing.exposure_half_lines == 7103);
    assert(writes == 0 && ready_count == 0 && reset_count == 0);
    static const uint16_t address[] = {0x320c,0x320d,0x320e,0x320f,0x3e00,0x3e01,0x3e02};
    for (unsigned i = 0; i < 7; ++i) {
        reset_model(0); fail_at = (int)i;
        timing = (struct camera_timing){123,456,789};
        struct camera_result result = camera_get_timing(&timing);
        assert(result.code == I2C_TIMEOUT_ERROR && result.reg == address[i]);
        assert(result.index == i && operations == i + 1 && writes == 0);
        assert(timing.hts == 123 && timing.vts == 456 && timing.exposure_half_lines == 789);
    }
    printf("PASS camera: P1 standby/timing/readback/stream order, legacy profile removed, %u injected I2C faults, %u readback mismatches, timing decode and 7 read failures\n", faults, mismatches);
}
