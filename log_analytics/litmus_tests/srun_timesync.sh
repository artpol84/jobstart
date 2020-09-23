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

if [ -z "$SLURM_BASE" ]; then
    SLURM_BASE=/tmp/slurm_deploy/ompi/
fi

SRUN=$SLURM_BASE/bin/srun

export OMPI_MCA_PML="ucx"
export OMPI_MCA_BTL="self"

$SRUN --mpi=pmix $MPISYNC -o $OUTFILE
