#!/bin/bash
# usage: exp.sh <label>   (15 rounds, nb4 and nb32)
S=/tmp/claude-1000/-home-mb/41989768-b1a0-4c9f-8051-97dd61788b75/scratchpad
cd $S/k73 && D=$S/k73 I1=$S/libiio1_host/inst NBS=4,32 RUNS=${RUNS:-15} python3 drop73.py > exp_$1.log 2>&1
tail -3 exp_$1.log
