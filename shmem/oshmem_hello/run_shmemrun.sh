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

. env.sh

type=$1
test_set_env $type

export OMPI_MCA_btl_openib_warn_default_gid_prefix=0

PML_COMPONENT="--mca pml yalla"

echo "Default symkey:"
for i in `seq 1 10`; do
    echo -n "nodes $SLURM_NNODES "
    shmemrun $PML_COMPONENT --map-by node ./hello_oshmem_$test_env_type
done    

echo "DC + symkey=$TEST_SYMKEY_SIZE"
for i in `seq 1 10`; do
    echo -n "nodes $SLURM_NNODES "
    shmemrun $PML_COMPONENT -x MXM_OSHMEM_TLS=dc -x SHMEM_SYMMETRIC_HEAP_SIZE=$TEST_SYMKEY_SIZE --map-by node ./hello_oshmem_$test_env_type
done

echo "UD + symkey=$TEST_SYMKEY_SIZE"
for i in `seq 1 10`; do
    echo -n "nodes $SLURM_NNODES "
    shmemrun $PML_COMPONENT -x MXM_OSHMEM_TLS=ud,self -x SHMEM_SYMMETRIC_HEAP_SIZE=$TEST_SYMKEY_SIZE --map-by node ./hello_oshmem_$test_env_type
done
