#include <assert.h>
#include <stdio.h>
#include "platform.h"
#include "camera.h"
#include "camera_table.h"

static uint32_t timer, camera_control;
static unsigned writes, reads, ready_count, reset_count, inits;
static int fail_write, fail_read, mismatch;
static void reset_model(void) {
    timer = 0xffff0000u; camera_control = 1;
    writes = reads = ready_count = reset_count = inits = 0;
    fail_write = fail_read = mismatch = -1;
}
uint32_t mmio_read(uint32_t address) {
    assert(address == CLINT_MTIME);
    timer += 1000000u;
    return timer;
}
void mmio_write(uint32_t address, uint32_t value) {
    assert(address == CONTROL_BASE + REG_CAMERA);
    assert(value <= 2u);
    if (value == CAMERA_RESET) ++reset_count;
    if (value == CAMERA_READY) ++ready_count;
    camera_control = value;
}
void i2c_init(void) { ++inits; }
enum i2c_result camera_write(uint16_t address, uint8_t value) {
    assert(camera_control == 0u && writes < CAMERA_REGISTER_COUNT);
    assert(camera_registers[writes].address == address && camera_registers[writes].value == value);
    return (int)writes++ == fail_write ? I2C_NACK_ERROR : I2C_OK;
}
enum i2c_result camera_read(uint16_t address, uint8_t *value) {
    static const uint16_t expected_address[] = {0x3208, 0x3209, 0x320a, 0x320b, 0x0100};
    static const uint8_t expected_value[] = {7, 128, 4, 56, 1};
    assert(writes == CAMERA_REGISTER_COUNT && reads < 5u && camera_control == 0u);
    assert(address == expected_address[reads]);
    *value = (uint8_t)(expected_value[reads] ^ ((int)reads == mismatch));
    return (int)reads++ == fail_read ? I2C_TIMEOUT_ERROR : I2C_OK;
}
int main(void) {
    reset_model();
    struct camera_result result = camera_configure();
    assert(result.code == I2C_OK && writes == 164 && reads == 5 && ready_count == 1 && inits == 1);
    assert(reset_count == 1 && camera_control == CAMERA_READY);
    for (int i = 0; i < 164; ++i) {
        reset_model(); fail_write = i; result = camera_configure();
        assert(result.code == I2C_NACK_ERROR && result.index == (unsigned)i);
        assert(result.reg == camera_registers[i].address);
        assert(writes == (unsigned)i + 1 && reads == 0 && ready_count == 0 && camera_control == CAMERA_RESET);
    }
    for (int i = 0; i < 5; ++i) {
        reset_model(); fail_read = i; result = camera_configure();
        assert(result.code == I2C_TIMEOUT_ERROR && ready_count == 0 && camera_control == CAMERA_RESET);
        reset_model(); mismatch = i; result = camera_configure();
        assert(result.code == CAMERA_VERIFY_ERROR && result.index == (unsigned)i + 164);
        assert(ready_count == 0 && camera_control == CAMERA_RESET);
    }
    puts("PASS camera: exact 164-write ordering, 5 readbacks, each of 164 NACK locations, each readback timeout/mismatch, fail-closed ready gating");
}
