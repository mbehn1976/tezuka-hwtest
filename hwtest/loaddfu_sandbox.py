"""Run the old and new `loaddfu` U-Boot helper in U-Boot sandbox and check what reaches the SPI flash.

Sandbox: U-Boot 2025.01 (the tezuka U-Boot tree) built as sandbox, with an SD card (mmc 0) backed by a FAT
image and a 16 MiB n25q128a SPI flash backed by spi.bin (the sandbox flash emulator does not do the
4-byte addressing of larger parts), so the FIT area is 0x200000-0x1000000 (14 MiB), as on the 16 MiB boards. Each case starts from an erased (0xFF) flash.
Usage: loaddfu_sandbox.py <u-boot> <sandbox.dtb> <workdir> <env-old.txt> <env-new.txt> <mcopy>
"""
import os, subprocess, sys, json

UBOOT, DTB, WD, ENV_OLD, ENV_NEW, MCOPY = sys.argv[1:7]
FLASH = 16 * 1024 * 1024
FIT_OFF, ENV_OFF = 0x200000, 0x100000


def env_var(path, name):
    """The value of one variable from a mkenvimage text file (backslash-newline continuations joined)."""
    text = open(path).read().replace('\\\n', '')
    for line in text.splitlines():
        if line.startswith(name + '='):
            return line[len(name) + 1:]
    raise KeyError(name)


def run_case(env_path, files):
    os.chdir(WD)
    for f in ('sd.img', 'spi.bin'):
        if os.path.exists(f):
            os.remove(f)
    subprocess.run(['mkfs.vfat', '-C', 'sd.img', str(64 * 1024)], check=True, capture_output=True)
    for name, data in files.items():
        open(name, 'wb').write(data)
        subprocess.run([MCOPY, '-i', 'sd.img', name, '::' + name], check=True)
        os.remove(name)
    open('spi.bin', 'wb').write(b'\xff' * FLASH)
    with open('env.txt', 'w') as f:
        f.write('fit_load_address=0x2080000\nfit_config=config@0\nloaddfu=%s\n' % env_var(env_path, 'loaddfu'))
    cmds = 'load hostfs - 0x1000000 env.txt && env import -t 0x1000000 ${filesize} && run loaddfu'
    out = subprocess.run([UBOOT, '-m', '256', '-d', DTB, '-c', cmds], capture_output=True, text=True, timeout=120)
    flash = open('spi.bin', 'rb').read()
    return out.stdout, flash


def region(flash, off, data_len):
    """Describe what is in flash[off:off+data_len] and how far past it the flash was written."""
    seg = flash[off:off + data_len]
    last = len(flash.rstrip(b'\xff'))
    return seg, last


def main():
    rnd = lambda n: os.urandom(n)
    fit2 = rnd(2_000_000)
    fit12 = rnd(12 * 1024 * 1024)
    fit15 = rnd(15 * 1024 * 1024)
    env = rnd(0x20000)
    cases = {
        'good files': {'pluto.dfu': fit2, 'uboot-env.dfu': env},
        'pluto.dfu missing': {'uboot-env.dfu': env},
        'pluto.dfu 12 MiB': {'pluto.dfu': fit12, 'uboot-env.dfu': env},
        'uboot-env.dfu missing': {'pluto.dfu': fit2},
        'uboot-env.dfu 1000 bytes': {'pluto.dfu': fit2, 'uboot-env.dfu': env[:1000]},
        'pluto.dfu 15 MiB (> 14 MiB FIT area)': {'pluto.dfu': fit15, 'uboot-env.dfu': env},
    }
    res = {}
    for cname, files in cases.items():
        for ver, envp in (('old', ENV_OLD), ('new', ENV_NEW)):
            out, flash = run_case(envp, files)
            fit = files.get('pluto.dfu', b'')
            envd = files.get('uboot-env.dfu', b'')
            fit_area = flash[FIT_OFF:]
            env_area = flash[ENV_OFF:ENV_OFF + 0x20000]
            r = {
                'fit_written_bytes': len(fit_area.rstrip(b'\xff')),
                'fit_matches_file': bool(fit) and fit_area[:len(fit)] == fit,
                'fit_area_erased': fit_area == b'\xff' * len(fit_area),
                'env_matches_file': len(envd) == 0x20000 and env_area == envd,
                'env_area_erased': env_area == b'\xff' * 0x20000,
                'bootm_attempted': 'bootm command' in out or "can't get kernel image" in out,
                'messages': [l.strip() for l in out.splitlines() if any(k in l for k in
                             ('missing', 'not updated', 'failed', 'written', 'bytes read', 'Unable', 'exceeds', 'Error'))][:6],
            }
            res.setdefault(cname, {})[ver] = r
    print(json.dumps(res, indent=1))


main()
