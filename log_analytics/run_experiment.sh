#!/bin/bash

function get_ts()
{
    local nsec=`date +%s%N`
    local s=`expr $nsec / 1000000000`
    local ns=`expr $nsec % 1000000000`
    echo "$s.$ns"
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
    echo `get_ts` > $base/extern_timings
    $probe_script $@ $alog
    echo `get_ts` >> $base/extern_timings
    pdsh -w $SLURM_JOB_NODELIST `pwd`/collect_logs.sh `pwd` $slog
}

BASEDIR=$1
run_one_probe $BASEDIR/mpi `pwd`/litmus_tests/srun_mpi_probe.sh
run_one_probe $BASEDIR/pmix `pwd`/litmus_tests/srun_pmix_probe.sh
