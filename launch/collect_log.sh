#
# Copyright (C) 2017      Mellanox Technologies, Inc.
#                         All rights reserved.
# $COPYRIGHT$
#
# Additional copyrights may follow
#
# $HEADER$
#

#!/bin/bash

cd <thisdir>

source common.sh
source ../slurm_deploy/deploy_ctl.conf

set -x
mkdir logs/
#cat /tmp/boriska_slurm/var/slurmd.log | grep "mpi_pmix init" >> logs/common.log
cp $INSTALL_DIR/slurm/var/slurmd.log logs/`hostname`

#clear log
echo "" > $INSTALL_DIR/slurm/var/slurmd.log