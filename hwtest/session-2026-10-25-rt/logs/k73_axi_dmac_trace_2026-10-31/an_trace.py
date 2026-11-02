import sys, re, collections, statistics as st
ev=[]
for l in open(sys.argv[1]):
    if l.startswith('#'): continue
    m=re.match(r'\s*(\S+)-(\d+)\s+\[(\d+)\]\s+\S+\s+([\d.]+):\s+(\S+)',l)
    if m: ev.append((float(m.group(4)),m.group(5),m.group(1),int(m.group(3))))
ev.sort()
c=collections.Counter(e[1] for e in ev); print(dict(c))
T0=ev[0][0]; T1=ev[-1][0]; print('span %.2f s'%(T1-T0))
depth=0; hist=collections.Counter(); mind=99; idle=[]; last=None
done=[]; deq=[]; enq=[]; subs=[]
idle_start=None
for t,f,task,cpu in ev:
    if f in ('iio_dma_buffer_submit_block','iio_dmaengine_buffer_submit_block'): depth+=1; subs.append(t)
    if f=='iio_dma_buffer_block_done':
        depth-=1; done.append(t)
        if depth<=0: idle_start=t
        if f=='axi_dmac_start_transfer' and idle_start is not None: pass
    if f in ('iio_dma_buffer_submit_block','iio_dmaengine_buffer_submit_block') and idle_start is not None:
        idle.append(t-idle_start); idle_start=None
    hist[depth]+=1
print('depth (submitted, not done) min %d max %d; share of events at depth<=0: %.3f'%(min(hist),max(hist),sum(v for k,v in hist.items() if k<=0)/sum(hist.values())))
print('queue-empty episodes (depth<=0 after done until next submit): n=%d, us: %s'%(len(idle),sorted(int(x*1e6) for x in idle)[-8:]))
d=[ (done[i+1]-done[i])*1e3 for i in range(len(done)-1)]
print('block_done interval ms: n=%d min %.2f med %.2f max %.2f'%(len(d),min(d),st.median(d),max(d)))
# user side
q=[e for e in ev if e[1]=='iio_dma_buffer_dequeue_block']; en=[e[0] for e in ev if e[1]=='iio_dma_buffer_enqueue_block']
print('dequeue n',len(q),'enqueue n',len(en),'done n',len(done),'submit n',len(subs))
lat=[]; 
import bisect
dq=[e[0] for e in q]
for t in done:
    i=bisect.bisect_left(dq,t)
    if i<len(dq): lat.append((dq[i]-t)*1e6)
lat.sort(); print('block_done -> next dequeue us: med %.0f p99 %.0f max %.0f'%(lat[len(lat)//2],lat[int(len(lat)*.99)],lat[-1]))
# time between a block completing and being resubmitted to HW
sl=[]
for t in done:
    i=bisect.bisect_left(subs,t)
    if i<len(subs): sl.append((subs[i]-t)*1e6)
sl.sort(); print('block_done -> next submit us: med %.0f p99 %.0f max %.0f'%(sl[len(sl)//2],sl[int(len(sl)*.99)],sl[-1]))
print('tasks submitting:',collections.Counter(e[2] for e in ev if e[1] in ('iio_dma_buffer_submit_block','iio_dmaengine_buffer_submit_block')).most_common(3))
