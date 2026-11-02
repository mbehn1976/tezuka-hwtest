import re,collections
ev=[]
for l in open('k73ev_nb4.txt'):
    if l.startswith('#'): continue
    m=re.match(r'\s*(.+?)-(\d+)\s+\[(\d+)\]\s+\S+\s+([\d.]+):\s+(\S+?):?\s(.*)',l)
    if m: ev.append((float(m.group(4)),m.group(1),int(m.group(2)),int(m.group(3)),m.group(5),m.group(6)))
ev.sort(key=lambda e:e[0])
done=[e[0] for e in ev if e[4]=='iio_dma_buffer_block_done']
enq=[e[0] for e in ev if e[4]=='iio_dma_buffer_enqueue_dmabuf']
nb=4
holds=[(enq[i+nb]-done[i],done[i],enq[i+nb]) for i in range(min(len(done),len(enq)-nb))]
holds.sort(reverse=True); print('worst holds ms',[round(h[0]*1e3) for h in holds[:8]])
def cpu_share(t0,t1):
    # per cpu: time per task from sched_switch next_comm
    run=collections.defaultdict(float); last={}
    for t,task,pid,cpu,f,rest in ev:
        if f!='sched_switch' or t<t0 or t>t1: continue
        m=re.search(r'next_comm=(.+?) next_pid',rest)
        if cpu in last:
            lt,ln=last[cpu]; run[(cpu,ln)]+=t-lt
        last[cpu]=(t,m.group(1) if m else '?')
    return run
for h,t0,t1 in holds[:2]:
    print('--- hold %.0f ms window %.4f..%.4f'%(h*1e3,t0,t1))
    r=cpu_share(t0,t1)
    for k,v in sorted(r.items(),key=lambda x:-x[1])[:10]: print('  cpu%d %-18s %.1f ms'%(k[0],k[1],v*1e3))
    c=collections.Counter((e[1],e[4]) for e in ev if t0<=e[0]<=t1 and e[4] in('sock_sendmsg','tcp_sendmsg','sock_recvmsg','iio_buffer_signal_dmabuf_done'))
    print('  calls:',dict(c))
