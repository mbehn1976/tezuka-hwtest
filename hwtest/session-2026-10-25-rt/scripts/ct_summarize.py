import sys,re
d=sys.argv[1]
for ph in ('idle','cpu2','heavy'):
    tot=0; mx=mn=avg=None; hist={}
    for l in open('%s/ct_%s.txt'%(d,ph)):
        m=re.match(r'^# Max Latencies: (\d+)',l)
        if m: mx=int(m.group(1))
        m=re.match(r'^# Avg Latencies: (\d+)',l)
        if m: avg=int(m.group(1))
        m=re.match(r'^# Min Latencies: (\d+)',l)
        if m: mn=int(m.group(1))
        m=re.match(r'^(\d{6})\s+(\d+)',l)
        if m: hist[int(m.group(1))]=int(m.group(2))
    n=sum(hist.values())
    def pct(p):
        c=0
        for k in sorted(hist):
            c+=hist[k]
            if c>=n*p: return k
    over=lambda t: sum(v for k,v in hist.items() if k>t)
    print('%-6s samples=%d min=%s avg=%s max=%s  p99=%s p99.9=%s p99.99=%s  >50us=%d >100us=%d >200us=%d'%(ph,n,mn,avg,mx,pct(.99),pct(.999),pct(.9999),over(50),over(100),over(200)))
