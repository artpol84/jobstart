#
# Copyright (C) 2017      Mellanox Technologies, Inc.
#                         All rights reserved.
# $COPYRIGHT$
#
# Additional copyrights may follow
#
# $HEADER$
#
#!/bin/bash -x

. ./deploy_ctl.sh

cmd=$1
shift

function print_help() {
    echo "Use:"
    echo ./`basename "$0"` "<cmd>"
    echo "      build_all                           build all projects"
    echo "      slurm_config                        "
    echo "      distribute_all"
    echo "      cleanup_all"
    echo "      slurm_update <light>"
    echo "      plugin_update"
    echo "      source_prepare                      download software, prepare configs"
    echo "      slurm_start"
    echo "      slurm_stop" 
}

case $cmd in
    build_all)
        deploy_build_all
        ;;
    slurm_config)
        config=$1
        shift
        deploy_slurm_config $config
        ;;
    distribute_all)
        deploy_distribute_all
        ;;
    slurm_update)
        deploy_slurm_update $1
        ;;
    plugin_update)
        deploy_slurm_pmix_update
        ;;
    source_prepare)
        deploy_source_prepare
        ;;
    cleanup_all)
        deploy_cleanup_all
        ;;
    slurm_stop)
        deploy_slurm_stop
        ;;
    slurm_start)
        deploy_slurm_start
        ;;
    *)
        print_help
        ;;
esac