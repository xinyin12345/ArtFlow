#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "console.h"

int main(void) {
    const char *invalid[] = {
        "wb", "wb 1 2", "wb 1 2 3 4", "wb -1 2 3", "wb +1 2 3",
        "wb 1025 2 3", "wb 4294967296 2 3", "wb 00000 2 3",
        "wb 1.2 2 3", "wb 0x100 2 3", "wb 1 2 3junk", "wb1 2 3",
        "status 1", "defaults now", "cam", "cam init extra", "cam on",
        "cam baseline extra", "cam timing 1", "cam baselineX", "cam timingX", "cam off extra", "help; cam init", "WB 1 2 3", "unknown"
    };
    struct command c = parse_command(" \twb 0 1024 255\t ");
    assert(c.kind == CMD_WB && c.rgb[0] == 0 && c.rgb[1] == 1024 && c.rgb[2] == 255);
    assert(parse_command("help").kind == CMD_HELP);
    assert(parse_command("status").kind == CMD_STATUS);
    assert(parse_command("defaults").kind == CMD_DEFAULTS);
    assert(parse_command("cam init").kind == CMD_CAM_INIT);
    assert(parse_command("cam off").kind == CMD_CAM_OFF);
    assert(parse_command("cam baseline").kind == CMD_CAM_BASELINE);
    assert(parse_command("cam timing").kind == CMD_CAM_TIMING);
    assert(parse_command(" \t").kind == CMD_EMPTY);
    for (unsigned i = 0; i < sizeof invalid / sizeof invalid[0]; ++i)
        assert(parse_command(invalid[i]).kind == CMD_INVALID);
    struct line_reader reader = { {0}, 0, 0 };
    const char *valid = "wb 280 255 350";
    for (const char *p = valid; *p; ++p) assert(line_feed(&reader, (unsigned char)*p) == 0);
    assert(line_feed(&reader, '\r') == 1);
    assert(strcmp(reader.data, valid) == 0);
    assert(line_feed(&reader, '\n') == 1); /* CRLF produces harmless empty line. */
    assert(parse_command(reader.data).kind == CMD_EMPTY);
    for (unsigned i = 0; i < 64; ++i) assert(line_feed(&reader, 'a') == 0);
    assert(line_feed(&reader, 8) == 0); /* An overflow cannot be edited into validity. */
    assert(line_feed(&reader, '\n') == -1);
    for (const char *p = valid; *p; ++p) line_feed(&reader, (unsigned char)*p);
    line_feed(&reader, 0); /* Embedded NUL must discard a valid command prefix. */
    assert(line_feed(&reader, '\n') == -1);
    line_feed(&reader, 'a'); line_feed(&reader, 8); line_feed(&reader, 'h');
    assert(line_feed(&reader, '\n') == 1 && strcmp(reader.data, "h") == 0);
    for (unsigned ch = 0x80; ch <= 0xff; ++ch) {
        line_feed(&reader, (unsigned char)ch);
        assert(line_feed(&reader, '\n') == -1);
    }
    puts("PASS console: valid commands, 25 malformed commands, bounds, CRLF, editing, all non-ASCII bytes");
}
