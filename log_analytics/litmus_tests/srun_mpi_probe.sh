#
# Copyright (C) 2016-2017 Mellanox Technologies, Inc.
#                         All rights reserved.
# $COPYRIGHT$
#
# Additional copyrights may follow
#
# $HEADER$
#

#!/bin/bash

if [ -z "$SRUN" ]; then
    SLURM_BASE=/tmp/slurm_deploy/slurm/
    SRUN=$SLURM_BASE/bin/srun
fi

export OMPI_MCA_PML="ucx"
export OMPI_MCA_BTL="self"
$SRUN  --mpi=pmix `dirname $0`/mpi_probe $1
