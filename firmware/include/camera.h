#ifndef ARTFLOW_CAMERA_H
#define ARTFLOW_CAMERA_H
#include <stdint.h>
enum i2c_result { I2C_OK, I2C_TIMEOUT_ERROR, I2C_NACK_ERROR, I2C_BUS_ERROR,
                  CAMERA_VERIFY_ERROR };
struct camera_result { enum i2c_result code; uint16_t reg; uint16_t index; };
void i2c_init(void);
enum i2c_result camera_write(uint16_t address, uint8_t value);
enum i2c_result camera_read(uint16_t address, uint8_t *value);
/* baseline=1 replays the preserved table exactly for an on-board A/B test. */
struct camera_result camera_configure(unsigned baseline);
struct camera_timing { uint16_t hts, vts, exposure_half_lines; };
struct camera_result camera_get_timing(struct camera_timing *timing);
#endif
