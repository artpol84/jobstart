#!/bin/bash

function get_ts()
{
    local nsec=`date +%s%N`
    local s=`expr $nsec / 1000000000`
    local ns=`expr $nsec % 1000000000`
    echo "$s.$ns"
}

function run_mpi_timesync()
{
    base=$1
    shift
    `pwd`/litmus_tests/mpirun_timesync.sh `pwd`/mpisync/mpisync $base/mpisync.out
}

function run_slurm_timesync()
{
    base=$1
    shift
    `pwd`/litmus_tests/srun_timesync.sh `pwd`/mpisync/mpisync $base/srun_mpisync.out
}

function run_one_probe()
{
    base=$1
    probe_script=$2
    shift 2
    
    alog=$base/app_logs
    slog=$base/slurm_logs
    mkdir -p $alog 
    mkdir -p $slog

    run_mpi_timesync $base
#    run_slurm_timesync $base

    echo `get_ts` > $base/extern_timings
    $probe_script $@ $alog
    echo `get_ts` >> $base/extern_timings
    pdsh -w $SLURM_JOB_NODELIST `pwd`/collect_logs.sh `pwd` $slog
}

# cleanup logs before run
# pdsh -w $SLURM_JOB_NODELIST `pwd`/cleanup_logs.sh `pwd`

BASEDIR=$1
run_one_probe $BASEDIR/mpi `pwd`/litmus_tests/srun_mpi_probe.sh
run_one_probe $BASEDIR/pmix `pwd`/litmus_tests/srun_pmix_probe.sh 50 $BASEDIR/pmix/app_logs
