#
# Copyright (C) 2020      Mellanox Technologies, Inc.
#                         All rights reserved.
# $COPYRIGHT$
#
# Additional copyrights may follow
#
# $HEADER$
#

#!/bin/bash

source env.sh

MPISYNC=$1
OUTFILE=$2
shift 2

if [ -z "$OMPI_BASE" ]; then
    OMPI_BASE=/tmp/slurm_deploy/ompi/
fi

MPIRUN=$OMPI_BASE/bin/mpirun

export OMPI_MCA_PML="ucx"
export OMPI_MCA_BTL="self"

$MPIRUN -n $SLURM_NNODES --pernode $MPISYNC -o $OUTFILE
