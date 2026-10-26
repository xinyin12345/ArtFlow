#include "console.h"

static int whitespace(char c) { return c == ' ' || c == '\t'; }
static const char *skip(const char *p) {
    while (whitespace(*p)) ++p;
    return p;
}
static int word(const char **cursor, const char *expected) {
    const char *p = *cursor;
    while (*expected && *p == *expected) { ++p; ++expected; }
    if (*expected || (*p && !whitespace(*p))) return 0;
    *cursor = skip(p);
    return 1;
}
static int gain(const char **cursor, uint16_t *value) {
    const char *p = *cursor;
    unsigned n = 0, digits = 0;
    while (*p >= '0' && *p <= '9') {
        n = n * 10u + (unsigned)(*p++ - '0');
        if (n > 1024u || ++digits > 4u) return 0;
    }
    if (!digits || (*p && !whitespace(*p))) return 0;
    *cursor = skip(p);
    *value = (uint16_t)n;
    return 1;
}
struct command parse_command(const char *line) {
    struct command result = { CMD_INVALID, {0, 0, 0} };
    const char *p = skip(line);
    if (!*p) result.kind = CMD_EMPTY;
    else if (word(&p, "help")) result.kind = CMD_HELP;
    else if (word(&p, "status")) result.kind = CMD_STATUS;
    else if (word(&p, "freeze")) result.kind = CMD_FREEZE;
    else if (word(&p, "live")) result.kind = CMD_LIVE;
    else if (word(&p, "pair")) result.kind = CMD_PAIR;
    else if (word(&p, "blend")) { if(gain(&p,&result.rgb[0]) && result.rgb[0]<=4)result.kind=CMD_BLEND; }
    else if (word(&p, "curtain")) { if(gain(&p,&result.rgb[0]) && result.rgb[0]<=960)result.kind=CMD_CURTAIN; }
    else if (word(&p, "window")) { if(gain(&p,&result.rgb[0]) && gain(&p,&result.rgb[1]) && gain(&p,&result.rgb[2]) && result.rgb[0]<960 && result.rgb[1]<540 && result.rgb[2]<3)result.kind=CMD_WINDOW; }
    else if (word(&p, "defaults")) result.kind = CMD_DEFAULTS;
    else if (word(&p, "wb")) {
        if (gain(&p, &result.rgb[0]) && gain(&p, &result.rgb[1]) &&
            gain(&p, &result.rgb[2])) result.kind = CMD_WB;
    } else if (word(&p, "cam")) {
        if (word(&p, "init")) result.kind = CMD_CAM_INIT;
        else if (word(&p, "off")) result.kind = CMD_CAM_OFF;
        else if (word(&p, "timing")) result.kind = CMD_CAM_TIMING;
    }
    if (*p) result.kind = CMD_INVALID;
    return result;
}
int line_feed(struct line_reader *reader, unsigned char byte) {
    if (byte == '\r' || byte == '\n') {
        int result = reader->rejected ? -1 : 1;
        reader->data[reader->used] = 0;
        reader->used = 0;
        reader->rejected = 0;
        return result;
    }
    if (reader->rejected) return 0;
    if (byte == 8u || byte == 127u) {
        if (reader->used) --reader->used;
    } else if ((byte >= 32u && byte <= 126u) || byte == '\t') {
        if (reader->used == LINE_CAPACITY - 1u) reader->rejected = 1;
        else reader->data[reader->used++] = (char)byte;
    } else {
        /* Reject embedded NUL/control/UTF-8 bytes rather than interpreting a
         * valid prefix and inadvertently changing gains. */
        reader->rejected = 1;
    }
    return 0;
}
