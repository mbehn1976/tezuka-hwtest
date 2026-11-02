import sys, numpy as np
from numpy.lib.stride_tricks import sliding_window_view as sw
FS=10e6; B=512
def medf(x,k): return np.median(sw(np.pad(x,k//2,mode='edge'),k),axis=1)
def analyse(path):
    d=np.fromfile(path,dtype='<i2'); z=d[0::2]+1j*d[1::2]
    sp=np.abs(np.fft.fft(z[:1<<18]*np.blackman(1<<18))); f0=np.fft.fftfreq(1<<18,1/FS)[sp.argmax()]
    y=(z*np.exp(-2j*np.pi*f0*np.arange(len(z))/FS))[:len(z)//B*B].reshape(-1,B).mean(1)
    dp=np.angle(y[1:]*np.conj(y[:-1])); dev=dp-medf(dp,101)
    idx=np.where(np.abs(dev)>.4)[0]; pos=(idx+1)*B
    return len(z), f0, pos, dev[idx]
if __name__=='__main__':
    n,f0,pos,dev=analyse(sys.argv[1])
    print('samples %d f0 %.4f MHz outliers %d  blocks(262144) %d'%(n,f0/1e6,len(pos),n//262144))
    print('pos mod 262144:',(pos%262144)[:12].tolist()); print('block idx:',(pos//262144)[:16].tolist()); print('dev:',np.round(dev[:12],2).tolist())
