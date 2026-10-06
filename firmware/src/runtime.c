#include <stddef.h>

/* GCC can emit memcpy for structure copies even in freestanding code. */
void *memcpy(void *destination, const void *source, size_t count) {
    unsigned char *to = destination;
    const unsigned char *from = source;
    while (count--) *to++ = *from++;
    return destination;
}
