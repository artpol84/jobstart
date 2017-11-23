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
. ./prepare_lib.sh

SLURM_SRC=$SRC_DIR/slurm # Where to find SLURM sources.

function create_dir() {
    if [ -z "$1" ]; then
        echo Can not create directory. Bad param.
        exit 1
    fi
    mkdir $1
}

function check_file() {
    file=$1
    if [ ! -f "$file" ]; then
        echo File \"$file\" not found. Can not continue.
        exit 1
    fi
}

function build_log() {
    echo `date +"%Y-%m-%d %H:%M:%S.%3N"` [$1]: $2 >> $BUILD_DIR/build.log
}

function build_item() {
    url=$1
    prefix=$2
    branch=$3
    commit=$4
    config=$5

    sdir=`pwd`

    if [ -z "$prefix" ]; then
        echo_error $LINENO "install directory does no set"
        exit 1
    fi

    build_log $name "clone from ${url} ${branch} ${commit}"
    
    cd $SRC_DIR
    local tmp=$(mktemp)
    if [ -n "$branch" ]; then
        git clone -b $branch $url | tee -a $tmp
    else
        git clone $url | tee -a $tmp
    fi
    repo_name=$(awk -F\' '/Cloning into/ {print $2}' $tmp)
    src=$SRC_DIR/$repo_name
    rm $tmp
    
    build=$src/.build

    cd $src
    if [ -n "$commit" ]; then
        git reset --hard $commit
        build_log $name "switch commit to $commit"
    fi
    
    build_log $name "run autogen"
    if [ -f "autogen.sh" ]; then
        ./autogen.sh || echo "Autogen failed"
    else
        ./autogen.pl || echo "Autogen failed"
    fi
    if [ 0 != $? ]; then
        build_log $name "autogen failed"
        exit 1
    fi

    create_dir $build
    cd $build

cat > $build/config.sh << EOF
#!/bin/bash

$src/configure --prefix=$prefix $config

EOF
    chmod +x $build/config.sh

    check_file $src/configure
    build_log $name "run configure"
    $build/config.sh || echo "Configure failed"
    if [ 0 != "$?" ]; then
        build_log "\"$name\" configure failed. Can not continue."
        exit 1
    fi
    CPU_NUM=`grep -c ^processor /proc/cpuinfo`
    build_log $name "run make"
    make -j $CPU_NUM install
    if [ 0 != "$?" ]; then
        build_log "\"$name\" build failed. Can not continue."
        echo "\"$name\" build failed. Can not continue."
        exit 1
    fi
    cd $sdir
    build_log $name "build $name complete"
}

function init_deploy() {
    if [ -d $DEPLOY_DIR ]; then
        echo "#" The deploy directory \"$DEPLOY_DIR\" is already exists 
        echo "#" Please remove this directory or set another deploy path in \"deploy_ctl.conf\"
        echo "#" Can not continue
        exit 1
    fi
    create_dir $DEPLOY_DIR
    create_dir $SRC_DIR
    create_dir $BUILD_DIR
    create_dir $INSTALL_DIR
}

function deploy_build_all() {
    local sdir=`pwd`
    init_deploy
    
    # build_item use:
    #   [1:git_url] [2:prefix] [3:branch] [4:commit] [5:config]
    
    # release-2.1.8-stable e7ff4ef on Jan 26
    build_item "https://github.com/libevent/libevent.git" "$LIBEV_INST" "" "e7ff4ef" ""
    # hwloc-1.11.8 e6559c7 on Sep 6
    build_item "https://github.com/open-mpi/hwloc.git" "$HWLOC_INST" "" "e6559c7" ""
    # PMIx
    build_item "https://github.com/pmix/pmix.git" "$PMIX_INST" "v2.0" "" "--with-libevent=$LIBEV_INST"
    # UCX master
    build_item "https://github.com/openucx/ucx.git" "$UCX_INST" "" "" ""
    
    if [ -z "$SLURM_URL" ]; then
        echo_error $LINENO ""
        exit 1
    fi

    git clone $SLURM_URL $SLURM_SRC
    cd $SLURM_SRC
    if [ -n "$SLURM_COMMIT" ]; then
        git checkout $SLURM_COMMIT
    fi
    slurm_build
    slurm_finalize_install

    # OMPI v3.1.x
    build_item "https://github.com/open-mpi/ompi.git" "$OMPI_INST" "v3.1.x" "" \
        "--enable-debug --enable-mpirun-prefix-by-default --with-pmix=$PMIX_INST --with-slurm=$SLURM_INST --with-pmi=$SLURM_INST --with-libevent=$LIBEV_INST --with-ucx=$UCX_INST $OMPI_EXTRA_CONFIG"

    cd $sdir
}

function deploy_slurm_update_ligth() {
    sdir=`pwd`
    slurm_build_update
    slurm_finalize_install
    slurm_distribute
    cd $sdir
}

function deploy_slurm_update() {
    sdir=`pwd`
    slurm_build_remove
    slurm_build
    slurm_finalize_install
    slurm_distribute
    cd $sdir
}

function deploy_slurm_config() {
    slurm_conf=$1
    
    if [ -n "$slurm_conf" ]; then
        if [ -f $slurm_conf ]; then
            echo_error $LINENO "Can not set Slurm config file: file does not exist"
            exit 1
        fi
        echo "Use config $slurm_conf"
        cp -f $slurm_conf $SLURM_INST/etc/slurm.conf
    else
        slurm_prepare_conf
    fi
}

function distribute_get_nodes()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    nodes=`get_node_list`

    head_node=`node_is_head`
    if [ ! -z $head_node ]; then
        nodes=`get_node_list_wo_head`
    fi
    echo $nodes
}

function deploy_distribute_all() {
    slurm_distribute

    nodes=`distribute_get_nodes`
    copy_remote_nodes $nodes $OMPI_INST/* $OMPI_INST
    copy_remote_nodes $nodes $PMIX_INST/* $PMIX_INST
    copy_remote_nodes $nodes $HWLOC_INST/* $HWLOC_INST
    copy_remote_nodes $nodes $LIBEV_INST/* $LIBEV_INST
    copy_remote_nodes $nodes $UCX_INST/* $UCX_INST    
}
