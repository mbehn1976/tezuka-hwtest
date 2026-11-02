/* membench: what can the Zynq CPU do per second with a 1 MiB block stream?
 * Cold source (64 MiB pool, bigger than the L2), 1 MiB blocks, 3 s per test:
 *   memcpy   = memcpy block -> private buffer
 *   scan     = memchr(0xA1) over the block (iiocap's scan, random data)
 *   copy+scan= both
 *   tmpfs    = write() the block to a file in /tmp (iio_readdev -> /tmp)
 * Usage: membench   (prints MB/s per test) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>

#define BLK (1 << 20)
#define POOL (64 << 20)
static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}
static volatile uint64_t sink;
int main(void)
{
    uint8_t *pool = malloc(POOL), *dst = malloc(BLK);
    uint64_t x = 88172645463325252ULL;
    for (size_t i = 0; i < POOL; i += 8) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; memcpy(pool + i, &x, 8); }
    const char *names[] = {"memcpy", "scan", "copy+scan", "tmpfs write"};
    for (int t = 0; t < 4; t++) {
        long long bytes = 0, hits = 0;
        int fd = -1;
        if (t == 3) { fd = open("/tmp/membench.bin", O_WRONLY | O_CREAT | O_TRUNC, 0600); }
        double t0 = now();
        size_t off = 0;
        while (now() - t0 < 3.0) {
            const uint8_t *p = pool + off;
            if (t == 0 || t == 2) { memcpy(dst, p, BLK); if (t == 2) p = dst; }
            if (t == 1 || t == 2) {
                const uint8_t *q = p, *e = p + BLK;
                while ((q = memchr(q, 0xA1, e - q))) { hits++; q++; }
            }
            if (t == 3) {
                if (write(fd, p, BLK) != BLK || (bytes > (96 << 20) && (lseek(fd, 0, SEEK_SET), 0))) break;
            }
            sink += dst[(bytes >> 20) & (BLK - 1)] + hits;
            bytes += BLK;
            off = (off + BLK) % POOL;
        }
        double dt = now() - t0;
        if (fd >= 0) { close(fd); unlink("/tmp/membench.bin"); }
        printf("%-12s %7.1f MB/s%s\n", names[t], bytes / dt / 1e6, t == 1 || t == 2 ? "" : "");
    }
    return 0;
}
