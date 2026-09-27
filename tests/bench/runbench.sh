#!/bin/bash
# Benchmarks lua5.1.dll builds: the same C lua.exe runs bench.lua with each DLL;
# ROUNDS runs per DLL (interleaved), best time per test is reported, plus ratios
# against the first DLL.  Run on an otherwise idle machine.
# usage: runbench.sh ROUNDS SCALE NAME=path/to/library:arch [...]
#   arch is win32, win64, linux64, linuxarm64, macx64 or macarm64 (selects the C lua in $REFDIR/<arch>)
# example: runbench.sh 3 1 C32=$REFDIR/win32/lua5.1.dll:win32 DEL32=build/delphi/win32/lua5.1.dll:win32
. "$(dirname "$0")/../env.sh"
HERE=$(cd "$(dirname "$0")" && pwd)
R=$1; SC=$2; shift 2
W=$TMPW/bench; rm -rf $W; mkdir -p $W
for c in "$@"; do
  n=${c%%=*}; rest=${c#*=}; dll=${rest%:*}; a=${rest##*:}
  plat $a; echo "$a" > $W/$n.arch
  mkdir -p $W/$n; cp "$REFDIR/$a/lua$EXE" $W/$n/; cp "$dll" $W/$n/$LUALIB; cp "$HERE/bench.lua" $W/$n/
done
for r in $(seq 1 $R); do
  for c in "$@"; do
    n=${c%%=*}
    plat $(cat $W/$n.arch)
    (cd $W/$n && $RUN ./lua$EXE bench.lua $SC > out$r.txt 2>&1)
  done
done
python3 - "$W" "$R" "$@" <<'PY'
import sys
W,R=sys.argv[1],int(sys.argv[2]); cfgs=[c.split('=')[0] for c in sys.argv[3:]]
data={}
for n in cfgs:
    best={}
    order=[]
    for r in range(1,R+1):
        for ln in open(f"{W}/{n}/out{r}.txt"):
            p=ln.split()
            if len(p)!=2: print(n, ln.strip()); continue
            if p[0] not in best: order.append(p[0]); best[p[0]]=1e9
            best[p[0]]=min(best[p[0]],float(p[1]))
    data[n]=(order,best)
order=data[cfgs[0]][0]
print("%-14s"%"test"+"".join("%12s"%n for n in cfgs)+"".join("%10s"%(n+"/"+cfgs[0]) for n in cfgs[1:]))
tot={n:0 for n in cfgs}
import math
geo={n:0 for n in cfgs[1:]}
for t in order:
    row="%-14s"%t
    for n in cfgs: v=data[n][1].get(t,float('nan')); row+="%12.3f"%v; tot[n]+=v
    for n in cfgs[1:]:
        ratio=data[n][1][t]/max(data[cfgs[0]][1][t],1e-9); geo[n]+=math.log(max(ratio,1e-9)); row+="%10.2f"%ratio
    print(row)
print("%-14s"%"TOTAL"+"".join("%12.3f"%tot[n] for n in cfgs)+"".join("%10.2f"%(tot[n]/max(tot[cfgs[0]],1e-9)) for n in cfgs[1:]))
print("%-14s"%"geomean ratio"+" "*12*len(cfgs)+"".join("%10.2f"%math.exp(geo[n]/len(order)) for n in cfgs[1:]))
PY
