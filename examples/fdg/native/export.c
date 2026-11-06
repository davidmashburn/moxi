// Application-owned file conversion, not a second Scene renderer.
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <spawn.h>
#include <unistd.h>
extern char **environ;

enum ExportStatus { EXPORT_OK, EXPORT_IO, EXPORT_DEPENDENCY, EXPORT_CONVERSION };

static int write_all(int fd, const char *data, size_t length) {
    while (length) {
        ssize_t count = write(fd, data, length);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return -1;
        data += count;
        length -= (size_t)count;
    }
    return 0;
}

// Write a sibling temporary file, then rename only after successful conversion.
// No shell expansion; paths, Unicode labels and metacharacters remain data.
int32_t fdg_write_export(const char *svg, const char *path, const char *format) {
    char *output = malloc(strlen(path) + 16);
    if (!output) return EXPORT_IO;
    sprintf(output, "%s.tmp.XXXXXX", path);
    int out = mkstemp(output);
    if (out < 0) { free(output); return EXPORT_IO; }
    int status = EXPORT_OK;
    if (!strcmp(format, "svg")) {
        if (write_all(out, svg, strlen(svg))) status = EXPORT_IO;
    } else {
        char input[] = "/tmp/moxi-fdg-export-XXXXXX";
        int in = mkstemp(input);
        if (in < 0) status = EXPORT_IO;
        else {
            if (write_all(in, svg, strlen(svg))) status = EXPORT_IO;
            if (close(in)) status = EXPORT_IO;
            if (status == EXPORT_OK) {
                const char *converter = getenv("MOXI_FDG_RSVG");
                if (!converter) converter = "rsvg-convert";
                char *args[] = {(char *)converter, "--format", (char *)format,
                    "--dpi-x", "96", "--dpi-y", "96", "--output", output, input, NULL};
                pid_t pid;
                int error = (strchr(converter, '/') && access(converter, X_OK))
                    ? errno : posix_spawnp(&pid, converter, NULL, NULL, args, environ);
                if (error) status = EXPORT_DEPENDENCY;
                else {
                    int result = 0;
                    pid_t waited;
                    do { waited = waitpid(pid, &result, 0); } while (waited < 0 && errno == EINTR);
                    if (waited < 0 || !WIFEXITED(result)) status = EXPORT_CONVERSION;
                    else if (WEXITSTATUS(result) == 127) status = EXPORT_DEPENDENCY;
                    else if (WEXITSTATUS(result)) status = EXPORT_CONVERSION;
                }
            }
            unlink(input);
        }
    }
    if (status == EXPORT_OK && strcmp(format, "svg")) {
        unsigned char magic[8] = {0};
        // librsvg can atomically replace the temporary output pathname.
        int converted = open(output, O_RDONLY);
        ssize_t count = converted < 0 ? -1 : read(converted, magic, sizeof(magic));
        if (converted >= 0) close(converted);
        if ((!strcmp(format, "png") && (count != 8 || memcmp(magic, "\211PNG\r\n\032\n", 8))) ||
            (!strcmp(format, "pdf") && (count < 5 || memcmp(magic, "%PDF-", 5))))
            status = EXPORT_CONVERSION;
    }
    if (close(out)) status = EXPORT_IO;
    if (status == EXPORT_OK && rename(output, path)) status = EXPORT_IO;
    unlink(output);
    free(output);
    return status;
}
