#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "usage: %s FILE OFFSET EXPECTED_HEX REPLACEMENT_HEX\n", argv[0]);
        return 2;
    }

    char *end = NULL;
    errno = 0;
    unsigned long long raw_offset = strtoull(argv[2], &end, 0);
    if (errno || !end || *end != '\0') {
        fprintf(stderr, "invalid offset: %s\n", argv[2]);
        return 2;
    }

    errno = 0;
    uint32_t expected = (uint32_t)strtoul(argv[3], &end, 16);
    if (errno || !end || *end != '\0') {
        fprintf(stderr, "invalid expected word: %s\n", argv[3]);
        return 2;
    }

    errno = 0;
    uint32_t replacement = (uint32_t)strtoul(argv[4], &end, 16);
    if (errno || !end || *end != '\0') {
        fprintf(stderr, "invalid replacement word: %s\n", argv[4]);
        return 2;
    }

    int fd = open(argv[1], O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open %s: %s\n", argv[1], strerror(errno));
        return 1;
    }

    uint32_t current = 0;
    if (pread(fd, &current, sizeof(current), (off_t)raw_offset) != sizeof(current)) {
        fprintf(stderr, "read %s at %#llx: %s\n", argv[1], raw_offset, strerror(errno));
        close(fd);
        return 1;
    }
    if (current != expected) {
        fprintf(stderr, "refusing patch: found %08x, expected %08x\n", current, expected);
        close(fd);
        return 1;
    }
    if (pwrite(fd, &replacement, sizeof(replacement), (off_t)raw_offset) != sizeof(replacement)) {
        fprintf(stderr, "write %s at %#llx: %s\n", argv[1], raw_offset, strerror(errno));
        close(fd);
        return 1;
    }
    if (fsync(fd) != 0) {
        fprintf(stderr, "fsync %s: %s\n", argv[1], strerror(errno));
        close(fd);
        return 1;
    }
    close(fd);
    return 0;
}
