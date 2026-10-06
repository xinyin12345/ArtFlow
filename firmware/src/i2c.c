#include "platform.h"
#include "camera.h"

/* Sapphire/Spinal I2C register protocol, verified against demo10 generated RTL
 * and the Efinix BSP. Unlike the sample's blocking helpers, every wait is bounded.
 * TX_ACK=0x301 releases SDA for the ninth clock; RX_ACK contains the slave ACK.
 * RX_ACK.valid is clear-on-read: read valid and value in ONE bus transaction. */
#define TX_DATA       0x00u
#define TX_ACK        0x04u
#define RX_DATA       0x08u
#define RX_ACK        0x0cu
#define MASTER        0x40u
#define SLAVE         0x44u
#define VALID         0x100u
#define LISTEN        0x200u
#define BUSY          1u
#define START         0x10u
#define STOP          0x20u
#define DROP          0x40u
#define RECOVER       0x80u
#define DROPPED       0xe00u
#define DEVICE_WRITE  0x60u /* SC431HAI 7-bit address 0x30. */
#define WAIT_TICKS    (CORE_HZ / 50u) /* 20 ms per phase. */
#define HW_TIMEOUT   (CORE_HZ / 100u - 1u)
#define HW_SETUP     (CORE_HZ / 2000000u - 1u)
_Static_assert(HW_TIMEOUT > 0u && HW_TIMEOUT <= 0xfffffu, "I2C timeout exceeds 20 bits");
_Static_assert(HW_SETUP > 0u && HW_SETUP <= 0x3fu, "I2C setup exceeds 6 bits");

static uint32_t rd(uint32_t offset) { return mmio_read(I2C_BASE + offset); }
static void wr(uint32_t offset, uint32_t value) {
    mmio_write(I2C_BASE + offset, value);
}
static enum i2c_result wait_clear(uint32_t offset, uint32_t mask) {
    uint32_t start = ticks();
    while (rd(offset) & mask)
        if (elapsed(start, WAIT_TICKS)) return I2C_TIMEOUT_ERROR;
    return I2C_OK;
}
void i2c_init(void) {
    wr(0x20u, 0u);  /* Interrupts disabled; the console owns this bus. */
    wr(0x28u, 3u);  /* Input sampling divider. */
    /* This generated core has a 20-bit timeout and a 6-bit setup counter.
     * 10 ms = 1,000,000 cycles; 500 ns = 50 cycles at 100 MHz. Wider values
     * silently truncate in hardware (the generic BSP example exceeds both). */
    wr(0x2cu, HW_TIMEOUT);
    wr(0x30u, HW_SETUP);
    wr(0x50u, CORE_HZ / 100000u / 2u);
    wr(0x54u, CORE_HZ / 100000u / 2u);
    wr(0x58u, CORE_HZ / 100000u);
    wr(RX_ACK, LISTEN);
    wr(RX_DATA, LISTEN);
}
static enum i2c_result start_bus(void) {
    wr(MASTER, START | DROPPED); /* W1C stale drop status before every start. */
    enum i2c_result result = wait_clear(MASTER, START);
    if (result != I2C_OK) return result;
    if ((rd(MASTER) & (DROPPED | BUSY)) != BUSY) return I2C_BUS_ERROR;
    /* STOP and DROP clear both LISTEN enables in this Sapphire revision.
     * Arm after START (including repeated START), not merely once at init;
     * otherwise the second transaction never produces RX_ACK.valid. */
    wr(RX_ACK, LISTEN);
    wr(RX_DATA, LISTEN);
    return I2C_OK;
}
static enum i2c_result stop_bus(void) {
    wr(MASTER, STOP | DROPPED);
    enum i2c_result result = wait_clear(MASTER, STOP | BUSY);
    if (result != I2C_OK) return result;
    return rd(MASTER) & DROPPED ? I2C_BUS_ERROR : I2C_OK;
}
static void recover_bus(void) {
    /* Best effort cleanup, also bounded if SDA/SCL is physically stuck low. */
    (void)stop_bus();
    wr(MASTER, DROP | DROPPED);
    (void)wait_clear(MASTER, DROP | BUSY);
    wr(TX_DATA, 0u);
    wr(TX_ACK, 0u);
    (void)rd(RX_DATA);
    (void)rd(RX_ACK);
    wr(MASTER, RECOVER | DROPPED);
    (void)wait_clear(MASTER, RECOVER | BUSY);
    wr(MASTER, DROP | DROPPED);
    (void)wait_clear(MASTER, DROP | BUSY);
}
static enum i2c_result transmit(uint8_t value) {
    uint32_t start, ack;
    (void)rd(RX_ACK); /* Discard stale receive flag before queuing a new byte. */
    (void)rd(RX_DATA);
    wr(TX_DATA, (uint32_t)value | 0xb00u);
    wr(TX_ACK, 0x301u);
    start = ticks();
    for (;;) {
        ack = rd(RX_ACK);
        if (ack & VALID) break;
        if (elapsed(start, WAIT_TICKS)) return I2C_TIMEOUT_ERROR;
        if ((rd(MASTER) & (DROPPED | BUSY)) != BUSY) return I2C_BUS_ERROR;
    }
    if (ack & 1u) return I2C_NACK_ERROR;
    return I2C_OK;
}
static enum i2c_result address_register(uint16_t address) {
    enum i2c_result result = start_bus();
    if (result == I2C_OK) result = transmit(DEVICE_WRITE);
    if (result == I2C_OK) result = transmit((uint8_t)(address >> 8));
    if (result == I2C_OK) result = transmit((uint8_t)address);
    return result;
}
static enum i2c_result finish(enum i2c_result result) {
    if (result == I2C_OK) result = stop_bus();
    if (result != I2C_OK) recover_bus();
    return result;
}
enum i2c_result camera_write(uint16_t address, uint8_t value) {
    enum i2c_result result = address_register(address);
    if (result == I2C_OK) result = transmit(value);
    return finish(result);
}
enum i2c_result camera_read(uint16_t address, uint8_t *value) {
    enum i2c_result result = address_register(address);
    if (result == I2C_OK) result = start_bus(); /* Repeated START. */
    if (result == I2C_OK) result = transmit(DEVICE_WRITE | 1u);
    if (result == I2C_OK) {
        uint32_t start, data;
        (void)rd(RX_DATA);
        (void)rd(RX_ACK);
        /* Receive 8 clocks with SDA released. Disable-on-conflict MUST be 0
         * here: slave data bits of zero are expected, not arbitration losses. */
        wr(TX_DATA, 0x3ffu);
        wr(TX_ACK, 0x301u); /* Master NACK terminates this one-byte read. */
        start = ticks();
        for (;;) {
            data = rd(RX_DATA);
            if (data & VALID) { *value = (uint8_t)data; break; }
            if (elapsed(start, WAIT_TICKS)) { result = I2C_TIMEOUT_ERROR; break; }
            if ((rd(MASTER) & (DROPPED | BUSY)) != BUSY) {
                result = I2C_BUS_ERROR; break;
            }
        }
        if (result == I2C_OK) result = wait_clear(TX_ACK, VALID);
    }
    return finish(result);
}
