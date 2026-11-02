import re,sys
def load(fn):
    done=[];enq=[]
    for l in open(fn):
        m=re.match(r'\s*(\S+)-(\d+)\s+\[(\d+)\]\s+\S+\s+([\d.]+):\s+(\S+)',l)
        if not m: continue
        t=float(m.group(4)); f=m.group(5)
        if f=='iio_dma_buffer_block_done': done.append(t)
        if f in('iio_dma_buffer_enqueue_block','iio_dma_buffer_enqueue_dmabuf'): enq.append(t)
    return done,enq
for fn,nb in [('k612_nb4',4),('k73_nb4',4),('k612_nb32',32),('k73_nb32',32)]:
    d,e=load(fn+'.txt')
    h=sorted((e[i+nb]-d[i])*1e3 for i in range(min(len(d),len(e)-nb)))
    n=len(h); print('%-10s hold ms (block_done -> same block re-enqueued, n=%d): med %.1f p90 %.1f p99 %.1f max %.1f; >60ms: %d'%(fn,n,h[n//2],h[int(n*.9)],h[int(n*.99)],h[-1],sum(1 for x in h if x>60)))
