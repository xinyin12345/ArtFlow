#ifndef ARTFLOW_PLATFORM_H
#define ARTFLOW_PLATFORM_H
#include <stdint.h>

/* Addresses audited against the imported demo10 generated RTL, NOT its stale
 * settings.json. All control traffic bypasses the video DDR fabric. */
#define CORE_HZ       100000000u
#define UART_BASE     0xf8010000u
#define I2C_BASE      0xf8016000u
#define CONTROL_BASE  0xf8100000u
#define CLINT_MTIME   0xf8b0bff8u
#define CONTROL_ID    0x41524605u
#define REG_ID        0x00u
#define REG_STATUS    0x04u
#define REG_SHADOW_R  0x10u
#define REG_SHADOW_G  0x14u
#define REG_SHADOW_B  0x18u
#define REG_COMMIT    0x1cu
#define REG_ACTIVE_R  0x20u
#define REG_ACTIVE_G  0x24u
#define REG_ACTIVE_B  0x28u
#define REG_CAMERA    0x30u
#define STATUS_BUSY  1u
#define CAMERA_RESET 1u
#define CAMERA_READY 2u
#define DEFAULT_R    280u
#define DEFAULT_G    255u
#define DEFAULT_B    350u

#ifdef ARTFLOW_HOST_TEST
uint32_t mmio_read(uint32_t address);
void mmio_write(uint32_t address, uint32_t value);
#else
static inline uint32_t mmio_read(uint32_t address) {
    return *(volatile uint32_t *)(uintptr_t)address;
}
static inline void mmio_write(uint32_t address, uint32_t value) {
    *(volatile uint32_t *)(uintptr_t)address = value;
}
#endif
static inline uint32_t ticks(void) { return mmio_read(CLINT_MTIME); }
/* Unsigned subtraction deliberately tolerates the 32-bit timer rollover.
 * All requested waits are shorter than one wrap (42.95 s at 100 MHz). */
static inline int elapsed(uint32_t since, uint32_t duration) {
    return (uint32_t)(ticks() - since) >= duration;
}
static inline void delay_ms(uint32_t ms) {
    uint32_t start = ticks();
    while (!elapsed(start, ms * (CORE_HZ / 1000u))) { }
}
static inline uint32_t control_read(uint32_t offset) {
    return mmio_read(CONTROL_BASE + offset);
}
static inline void control_write(uint32_t offset, uint32_t value) {
    mmio_write(CONTROL_BASE + offset, value);
}
#endif
