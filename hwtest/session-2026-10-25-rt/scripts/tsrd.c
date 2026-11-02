/* tsrd <uri> <nblocks> <block_samples> <seconds> <outfile>: libiio 1.0 stream reader that only timestamps each block.
 * Writes "k t_before_ns t_after_ns" (CLOCK_MONOTONIC) per iio_stream_get_next_block call. Data is discarded. */
#include <iio/iio.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static unsigned long long now(void)
{
	struct timespec t;
	clock_gettime(CLOCK_MONOTONIC, &t);
	return t.tv_sec * 1000000000ull + t.tv_nsec;
}

int main(int argc, char **argv)
{
	if (argc < 6) { fprintf(stderr, "usage: tsrd uri nblocks block_samples seconds outfile\n"); return 2; }
	unsigned nb = atoi(argv[2]), bs = atoi(argv[3]);
	double secs = atof(argv[4]);
	struct iio_context *ctx = iio_create_context(NULL, argv[1]);
	if (iio_err(ctx)) { fprintf(stderr, "context failed\n"); return 1; }
	struct iio_device *dev = iio_context_find_device(ctx, "cf-ad9361-lpc");
	if (!dev) { fprintf(stderr, "no device\n"); return 1; }
	struct iio_channel *i = iio_device_find_channel(dev, "voltage0", false), *q = iio_device_find_channel(dev, "voltage1", false);
	struct iio_channels_mask *mask = iio_create_channels_mask(iio_device_get_channels_count(dev));
	iio_channel_enable(i, mask); iio_channel_enable(q, mask);
	struct iio_buffer *buf = iio_device_get_buffer(dev, 0);
	struct iio_stream *st = iio_buffer_create_stream(buf, nb, bs, mask);
	if (iio_err(st)) { fprintf(stderr, "stream failed\n"); return 1; }
	unsigned long long *tb = malloc(sizeof(*tb) * 100000), *ta = malloc(sizeof(*ta) * 100000);
	int n = 0;
	unsigned long long t0 = now();
	while ((now() - t0) < (unsigned long long)(secs * 1e9) && n < 100000) {
		tb[n] = now();
		const struct iio_block *b = iio_stream_get_next_block(st);
		ta[n] = now();
		if (iio_err(b)) { fprintf(stderr, "get_next_block failed\n"); break; }
		n++;
	}
	FILE *f = fopen(argv[5], "w");
	for (int k = 0; k < n; k++) fprintf(f, "%d %llu %llu\n", k, tb[k], ta[k]);
	fclose(f);
	iio_stream_destroy(st); iio_context_destroy(ctx);
	return 0;
}
