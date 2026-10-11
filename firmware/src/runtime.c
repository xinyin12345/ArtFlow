#include <stddef.h>

/* GCC can emit memcpy for structure copies even in freestanding code. */
/* Keep the out-of-line symbol: LTO may lower a structure copy to memcpy
 * after its whole-program symbol elimination pass. */
__attribute__((used, externally_visible))
void *memcpy(void *destination, const void *source, size_t count) {
    unsigned char *to = destination;
    const unsigned char *from = source;
    while (count--) *to++ = *from++;
    return destination;
}
