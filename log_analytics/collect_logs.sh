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

BASE_DIR=$1
TARGET_DIR=$2

. $BASE_DIR/env.sh
cp $SLURM_BASE/var/slurmd.log $TARGET_DIR/`hostname`
