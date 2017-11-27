#!/bin/bash

function setup_pp()
{
    start_size=${1:-0}
    end_size=${2:-23}
    same_thr=${3:-false}
    small_rep=${4:-100}
    large_rep=${5:-20}
    
    export SLURM_PMIX_PP_SAME_THR="$same_thr"
    export SLURM_PMIX_WANT_PP=1
    export SLURM_PMIX_PP_LOW_PWR2=$start_size
    export SLURM_PMIX_PP_UP_PWR2=$end_size
    export SLURM_PMIX_PP_ITER_SMALL=$small_rep
    export SLURM_PMIX_PP_ITER_LARGE=$large_rep
}

function setup_sapi()
{
    export SLURM_PMIX_DIRECT_CONN="false"
}

function setup_dtcp()
{
    export SLURM_PMIX_DIRECT_CONN="true"
    export SLURM_PMIX_DIRECT_CONN_UCX="false"
}

function setup_ducx()
{
    local ucx_dev=${1:-mlx5_0:1}
    local ucx_tls=${2:-rc}
    export SLURM_PMIX_DIRECT_CONN="true"
    export SLURM_PMIX_DIRECT_CONN_UCX="true"
    export UCX_NET_DEVICES=$ucx_dev
    export UCX_TLS=$ucx_tls
    
}

function setup_common()
{
    source config.sh
    export SLURM_PMIX_TIMEOUT=1000000
    export LD_LIBRARY_PATH="${TEST_PMIX_BASE}/lib/:$LD_LIBRARY_PATH"
    ulimit -c unlimited
}