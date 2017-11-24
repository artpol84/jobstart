#
# Copyright (C) 2016-2017 Mellanox Technologies, Inc.
#                         All rights reserved.
# $COPYRIGHT$
#
# Additional copyrights may follow
#
# $HEADER$
#

#!/bin/bash -x

SLURM_INST=$1

function kill_binary()
{
    name=$1
    if [ ! -f "$SLURM_INST/var/$name.pid" ]; then
        return 0
    fi
    pid=`cat $SLURM_INST/var/$name.pid`
    need_kill=`ps ax | grep "$pid" | grep $name`
    if [ -n "$need_kill" ]; then
        kill -KILL $pid
    fi
}

function kill_slurmd()
{
    kill_binary "slurmd"
}

function kill_ctld()
{
    kill_binary "slurmctld"
}

kill_slurmd
kill_ctld


