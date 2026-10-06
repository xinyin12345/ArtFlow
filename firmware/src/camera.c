#include "platform.h"
#include "camera.h"
#include "camera_table.h"

struct camera_result camera_configure(void) {
    struct camera_result result = { I2C_OK, 0, 0 };
    static const uint16_t verify_address[] = { 0x3208, 0x3209, 0x320a, 0x320b, 0x0100 };
    static const uint8_t verify_value[] = { 0x07, 0x80, 0x04, 0x38, 0x01 };
    /* Gating is removed only after every write and readback succeeds. */
    control_write(REG_CAMERA, CAMERA_RESET);
    delay_ms(20u);
    control_write(REG_CAMERA, 0u);
    delay_ms(50u);
    i2c_init();
    for (unsigned i = 0; i < CAMERA_REGISTER_COUNT; ++i) {
        result.index = (uint16_t)i;
        result.reg = camera_registers[i].address;
        result.code = camera_write(result.reg, camera_registers[i].value);
        if (result.code != I2C_OK) goto failed;
    }
    for (unsigned i = 0; i < sizeof verify_value; ++i) {
        uint8_t value;
        result.index = (uint16_t)(CAMERA_REGISTER_COUNT + i);
        result.reg = verify_address[i];
        result.code = camera_read(result.reg, &value);
        if (result.code != I2C_OK) goto failed;
        if (value != verify_value[i]) { result.code = CAMERA_VERIFY_ERROR; goto failed; }
    }
    control_write(REG_CAMERA, CAMERA_READY);
    return result;
failed:
    /* A failed transaction has already attempted bounded bus recovery. Keep
     * sensor reset asserted; cam init performs a full fresh initialization. */
    control_write(REG_CAMERA, CAMERA_RESET);
    return result;
}
