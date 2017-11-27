#!/bin/bash

source common.sh
source ../slurm_deploy/deploy_ctl.conf

setup_common

export OMPI_MCA_btl=self
export OMPI_MCA_pml=ucx

comm_set=0

while [ -n "$1" ]; do
    found=1
    # MAke sure that only one communication type was set
    if [ "$1" = "dtcp" ] || [ "$1" = "sapi" ] || [ "$1" = "ducx" ]; then
        if [ "$comm_set" != "0" ]; then
            echo "Duplicating communication settings in the cmdline"
            exit 1
        fi
        comm_set=1
    fi


    case "$1" in
    "dtcp")
        setup_dtcp
        shift
        ;;
    "sapi")
        setup_sapi
        shift
        ;;
    "ducx")
        setup_ducx $TEST_UCX_DEV $TEST_UCX_TLS
        shift
        ;;
    "early")
        export SLURM_PMIX_DIRECT_CONN_EARLY=true
        shift
        ;;
    "noearly")
        export SLURM_PMIX_DIRECT_CONN_EARLY=false
        shift
        ;;
    "openib")
        export OMPI_MCA_btl=self,vader,openib
        export OMPI_MCA_pml=ob1
        shift
        ;;
    "timing")
        export OMPI_TIMING_ENABLE=1
        shift
        ;;
    *)
        found=0
        ;;
    esac
    if [ "$found" = "0" ]; then
        break
    fi
done

export LD_LIBRARY_PATH="$INSTALL_DIR/ompi/lib":$LD_LIBRARY_PATH
export PATH=$INSTALL_DIR/slurm/bin:$PATH
export UCX_HANDLE_ERRORS=bt,freeze

if [ "$comm_set" = "0" ]; then
    # set default UCX
     setup_ducx $TEST_UCX_DEV $TEST_UCX_TLS
fi

srun --mpi=pmix --kill-on-bad-exit $@
