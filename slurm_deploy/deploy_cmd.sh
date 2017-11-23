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
    echo "      build_all"
    echo "      slurm_config"
    echo "      distribute_all [not tested]"
    echo "      slurm_update <light>"
    echo "      plugin_update [not implemented]"
    echo "      download_all [not implemented]"
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
        ligth=$1
        shift
        if [ "$light" = "ligth" ]; then
            deploy_slurm_update_ligth
        else
            deploy_slurm_update
        fi
        ;;
    plugin_update)
        ;;
    download_all)
        ;;
    *)
        print_help
        ;;
esac