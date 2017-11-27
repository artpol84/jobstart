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

. ./deploy_ctl.conf
. ./deploy_ctl.sh

if [ -f $DEPLOY_DIR/.deploy_env ]; then
    . $DEPLOY_DIR/.deploy_env
fi

cmd=$1
shift

function print_help() {
    echo "Use:"
    echo ./`basename "$0"` "<cmd>"
    echo "      build_all                           build all projects"
    echo "      slurm_config <config>               applyes the Slurm config to all nodes (requre to restart daemons)"
    echo "      distribute_all                      propagates the installed directories to the all nodes"
    echo "      cleanup_all                         cleans all install diretories, Slurm daemons will be stopped before cleaning"
    echo "      slurm_update <light>"
    echo "      plugin_update                       Slurm PMIx plugin rebuild and distribute to the all nodes"
    echo "      source_prepare                      download software, prepare configs"
    echo "      slurm_start                         run Slurm daemons"
    echo "      slurm_stop                          stop Slurm daemons" 
    echo "      ompi_remove_files                   removes the list of file from OMPI install dir, should be try before distributing"
    echo "                                          see the list of files to delete in the file: ompi_rm_files.txt"
}

case $cmd in
    build_all)
        deploy_build_all
        ;;
    slurm_config)
        config=$1
        shift
        slurm_prepare_conf $config
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
    ompi_remove_files)
        deploy_ompi_remove_files "ompi_rm_files.txt"
        ;;
    *)
        print_help
        ;;
esac