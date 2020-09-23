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

BASE_DIR=$1

. $BASE_DIR/env.sh
echo > $SLURM_BASE/var/slurmd.log
