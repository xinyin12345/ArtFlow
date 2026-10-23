#ifndef ARTFLOW_CONSOLE_H
#define ARTFLOW_CONSOLE_H
#include <stdint.h>
#define LINE_CAPACITY 64u
enum command_kind { CMD_EMPTY, CMD_HELP, CMD_STATUS, CMD_WB, CMD_DEFAULTS,
                    CMD_CAM_INIT, CMD_CAM_OFF, CMD_CAM_TIMING, CMD_INVALID };
struct command { enum command_kind kind; uint16_t rgb[3]; };
/* Parse the entire NUL-terminated line; no partial commands are executed. */
struct command parse_command(const char *line);
struct line_reader { char data[LINE_CAPACITY]; unsigned used; int rejected; };
/* 0=incomplete, 1=complete valid line, -1=discarded invalid/oversized line.
 * Caller consumes data immediately at completion; next byte starts a line. */
int line_feed(struct line_reader *reader, unsigned char byte);
#endif
