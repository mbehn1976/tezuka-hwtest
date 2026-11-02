/* ctxbench: cost of context switches and syscalls, for the Spectre v2 (BPIALL) comparison.
 * pipe: two processes bounce one byte through two pipes -> round trips per second (2 switches each)
 * syscall: getppid() in a loop -> calls per second
 * Usage: ctxbench [seconds]   prints median of 5 runs of each */
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

static double pipe_rate(double secs)
{
    int a[2], b[2];
    char c = 0;
    if (pipe(a) || pipe(b)) { perror("pipe"); exit(1); }
    pid_t pid = fork();
    if (pid == 0) {
        while (read(a[0], &c, 1) == 1 && c)
            if (write(b[1], &c, 1) != 1) break;
        _exit(0);
    }
    long n = 0;
    double t0 = now(), t1;
    c = 1;
    do {
        for (int i = 0; i < 1000; i++) {
            if (write(a[1], &c, 1) != 1 || read(b[0], &c, 1) != 1) { perror("io"); exit(1); }
        }
        n += 1000;
        t1 = now();
    } while (t1 - t0 < secs);
    c = 0;
    if (write(a[1], &c, 1) != 1) perror("stop");
    waitpid(pid, NULL, 0);
    close(a[0]); close(a[1]); close(b[0]); close(b[1]);
    return n / (t1 - t0);
}

static double syscall_rate(double secs)
{
    long n = 0;
    double t0 = now(), t1;
    do {
        for (int i = 0; i < 10000; i++)
            syscall(SYS_getppid);
        n += 10000;
        t1 = now();
    } while (t1 - t0 < secs);
    return n / (t1 - t0);
}

static int cmp(const void *x, const void *y)
{
    double a = *(const double *)x, b = *(const double *)y;
    return (a > b) - (a < b);
}

int main(int argc, char **argv)
{
    double secs = argc > 1 ? atof(argv[1]) : 2;
    double p[5], s[5];
    for (int i = 0; i < 5; i++) { p[i] = pipe_rate(secs); s[i] = syscall_rate(secs); }
    qsort(p, 5, sizeof p[0], cmp);
    qsort(s, 5, sizeof s[0], cmp);
    printf("pipe_roundtrips_per_s %.0f (min %.0f max %.0f)\n", p[2], p[0], p[4]);
    printf("getppid_per_s %.0f (min %.0f max %.0f)\n", s[2], s[0], s[4]);
    return 0;
}
