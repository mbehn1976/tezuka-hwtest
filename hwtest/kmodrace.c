/* kmodrace: race IOCTL_CACHEINV against mmap/munmap on the maia-sdr rxbuffer.
 * One thread maps and unmaps the buffer in a loop, the other issues IOCTL_CACHEINV
 * as fast as it can. With the user-VA invalidation in maia-kmod 0002-0004, an ioctl
 * that passed the mmap_done check can run a cache operation on an address munmap()
 * has just unmapped. Stop maia-httpd first (it holds the only allowed mapping).
 * Usage: kmodrace [seconds] [device] */
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define IOCTL_CACHEINV _IOW('M', 0, int)

static int fd;
static size_t size = 8 * 32768;
static volatile int stop;
static long maps, map_fail, inv_ok, inv_fail;

static void *mapper(void *arg)
{
    (void)arg;
    while (!stop) {
        void *p = mmap(NULL, size, PROT_READ, MAP_SHARED, fd, 0);
        if (p == MAP_FAILED) { map_fail++; continue; }
        maps++;
        munmap(p, size);
    }
    return NULL;
}

static void *invalidator(void *arg)
{
    (void)arg;
    unsigned n = 0;
    while (!stop) {
        if (ioctl(fd, IOCTL_CACHEINV, n++ % 8) == 0) inv_ok++; else inv_fail++;
    }
    return NULL;
}

int main(int argc, char **argv)
{
    int secs = argc > 1 ? atoi(argv[1]) : 30;
    const char *dev = argc > 2 ? argv[2] : "/dev/maia-sdr-spectrometer";
    fd = open(dev, O_RDONLY);
    if (fd < 0) { perror(dev); return 1; }
    pthread_t a, b;
    pthread_create(&a, NULL, mapper, NULL);
    pthread_create(&b, NULL, invalidator, NULL);
    for (int t = 0; t < secs; t++) {
        sleep(1);
        printf("t=%d maps=%ld map_fail=%ld inv_ok=%ld inv_fail=%ld\n", t + 1, maps, map_fail, inv_ok, inv_fail);
        fflush(stdout);
    }
    stop = 1;
    pthread_join(a, NULL);
    pthread_join(b, NULL);
    printf("done maps=%ld inv_ok=%ld inv_fail=%ld\n", maps, inv_ok, inv_fail);
    return 0;
}
