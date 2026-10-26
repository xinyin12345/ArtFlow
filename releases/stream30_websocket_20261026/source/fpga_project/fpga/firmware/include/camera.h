#ifndef ARTFLOW_CAMERA_H
#define ARTFLOW_CAMERA_H
#include <stdint.h>
enum i2c_result { I2C_OK, I2C_TIMEOUT_ERROR, I2C_NACK_ERROR, I2C_BUS_ERROR,
                  CAMERA_VERIFY_ERROR };
struct camera_result { enum i2c_result code; uint16_t reg; uint16_t index; };
void i2c_init(void);
enum i2c_result camera_write(uint16_t address, uint8_t value);
enum i2c_result camera_read(uint16_t address, uint8_t *value);
/* P1 only: standby, timing verification, stream enable; safe fresh recovery. */
struct camera_result camera_configure(void);
struct camera_timing { uint16_t hts, vts, exposure_half_lines; };
struct camera_result camera_get_timing(struct camera_timing *timing);
#endif
