#include "platform.h"
#include "camera.h"
#include "camera_table.h"

/* SC431HAI manual table 2-5: exposure is in half-lines, <= 2*VTS-11.
 * The preserved table requests 0x1bbf (7103), while VTS is left implicit.
 * P1 explicitly uses the documented default VTS=1500 and exposure=2989.
 * Do not infer an FPS from these values: sensor line time is not measured. */
struct camera_result camera_configure(void) {
    struct camera_result result = { I2C_OK, 0, 0 };
    static const uint16_t verify_address[] = {
        0x3208, 0x3209, 0x320a, 0x320b, 0x0100,
        0x320e, 0x320f, 0x3e00, 0x3e01, 0x3e02
    };
    static const uint8_t verify_value[] = { 7, 128, 4, 56, 1, 5, 220, 0, 186, 208 };
    unsigned operation = 0;
    /* Gating is removed only after every write and readback succeeds. */
    control_write(REG_CAMERA, CAMERA_RESET);
    delay_ms(20u);
    control_write(REG_CAMERA, 0u);
    delay_ms(50u);
    i2c_init();
    for (unsigned i = 0; i < CAMERA_REGISTER_COUNT; ++i) {
        uint8_t value = camera_registers[i].value;
        /* P1 finishes geometry and timing while still in standby. */
        if (camera_registers[i].address == 0x0100 && value == 1) continue;
        result.index = (uint16_t)operation++;
        result.reg = camera_registers[i].address;
        if (result.reg >= 0x3e00 && result.reg <= 0x3e02)
            value = verify_value[7u + result.reg - 0x3e00u];
        result.code = camera_write(result.reg, value);
        if (result.code != I2C_OK) goto failed;
    }
    {
        /* Write and verify VTS/exposure before allowing any streamed frame. */
        for (unsigned i = 5; i < 7; ++i) {
            result.index = (uint16_t)operation++;
            result.reg = verify_address[i];
            result.code = camera_write(result.reg, verify_value[i]);
            if (result.code != I2C_OK) goto failed;
        }
        for (unsigned i = 5; i < 10; ++i) {
            uint8_t value;
            result.index = (uint16_t)operation++;
            result.reg = verify_address[i];
            result.code = camera_read(result.reg, &value);
            if (result.code != I2C_OK) goto failed;
            if (value != verify_value[i]) { result.code = CAMERA_VERIFY_ERROR; goto failed; }
        }
        result.index = (uint16_t)operation++;
        result.reg = 0x0100;
        result.code = camera_write(result.reg, 1);
        if (result.code != I2C_OK) goto failed;
    }
    for (unsigned i = 0; i < 5; ++i) {
        uint8_t value;
        result.index = (uint16_t)operation++;
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

struct camera_result camera_get_timing(struct camera_timing *timing) {
    static const uint16_t address[] = { 0x320c, 0x320d, 0x320e, 0x320f, 0x3e00, 0x3e01, 0x3e02 };
    uint8_t value[7];
    struct camera_result result = { I2C_OK, 0, 0 };
    for (unsigned i = 0; i < 7; ++i) {
        result.index = (uint16_t)i;
        result.reg = address[i];
        result.code = camera_read(result.reg, &value[i]);
        if (result.code != I2C_OK) return result;
    }
    timing->hts = (uint16_t)((value[0] << 8) | value[1]);
    timing->vts = (uint16_t)(((value[2] & 0x7f) << 8) | value[3]);
    timing->exposure_half_lines = (uint16_t)(((value[4] & 15) << 12) | (value[5] << 4) | (value[6] >> 4));
    return result;
}
