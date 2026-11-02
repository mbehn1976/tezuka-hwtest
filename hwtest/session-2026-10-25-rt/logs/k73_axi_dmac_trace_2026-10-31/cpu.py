import re,sys,collections
def load(fn):
    ev=[]
    for l in open(fn):
        if l.startswith('#'): continue
        m=re.match(r'\s*(.+?)-(\d+)\s+\[(\d+)\]\s+\S+\s+([\d.]+):\s+(\S+?):?\s(.*)',l)
        if m: ev.append((float(m.group(4)),int(m.group(3)),m.group(5),m.group(6)))
    ev.sort(key=lambda e:e[0]); return ev
for fn in sys.argv[1:]:
    ev=load(fn); T0,T1=ev[0][0],ev[-1][0]; span=T1-T0
    run=collections.defaultdict(float); last={}
    for t,cpu,f,rest in ev:
        if f!='sched_switch': continue
        m=re.search(r'next_comm=(.+?) next_pid',rest)
        if cpu in last: run[(cpu,last[cpu][1])]+=t-last[cpu][0]
        last[cpu]=(t,m.group(1))
    print('==',fn,'span %.1f s'%span)
    for cpu in (0,1):
        idle=run.get((cpu,'swapper/%d'%cpu),0)
        print(' cpu%d busy %.0f%%'%(cpu,100*(1-idle/span)),end=' | ')
        top=sorted(((v,k[1]) for k,v in run.items() if k[0]==cpu and not k[1].startswith('swapper')),reverse=True)[:6]
        print(', '.join('%s %.0f%%'%(n,100*v/span) for v,n in top))
