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

shmemcc -o hello_oshmem_$test_env_type -g  hello_oshmem_c.c