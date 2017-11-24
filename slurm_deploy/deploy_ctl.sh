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
CPU_NUM=`grep -c ^processor /proc/cpuinfo`

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

function check_error() {
    echo $?
    if [ "$?" -ne "0" ]; then
        echo $1 $2
        exit 1
    fi
}

function item_download() {
    giturl=$1
    REPO_INST=$2
    branch=$3
    commit=$4
    config=$5
    
    sdir=`pwd`

    if [ -z "$giturl" ]; then
        echo_error $LINENO "github url was not set"
    fi
    if [ ! -d "$SRC_DIR" ]; then
        mkdir -p $SRC_DIR
        if [ ! -d $SRC_DIR ]; then
            echo_error $LINENO "source code directory cen not be created"
            exit 1
        fi
    fi
    cd $SRC_DIR

    local tmp=$(mktemp)
    if [ -n "$branch" ]; then
        git clone --progress -b $branch $giturl 2>&1 | tee -a $tmp
    else
        git clone --progress $giturl 2>&1 | tee -a $tmp
    fi
    if [ "0" -ne "${PIPESTATUS[0]}" ]; then
        repo_name=$(awk -F\' '/fatal: destination path/ {print $2}' $tmp)    
        existed=`cat $tmp | grep "destination path '$repo_name' already exists"`
        if [ -z "$existed" ]; then
            echo_error $LINENO "Can not clone '$repo_name' repo"
            exit 1
        fi
        echo_error $LINENO " \"$repo_name\" repository already exists, continue..."
    else
        repo_name=$(awk -F\' '/Cloning into/ {print $2}' $tmp)
    fi
    rm $tmp

    REPO_NAME=$repo_name
    REPO_SRC=$SRC_DIR/$repo_name
    if [ -z "$REPO_INST" ]; then
        REPO_INST=$INSTALL_DIR/$repo_name
    fi
    cd $REPO_SRC
    if [ -n "$commit" ]; then
        git reset --hard $commit
    fi
    build=$REPO_SRC/.build
    #rm -rf .build
    if [ ! -d ".build" ]; then
        create_dir .build
    fi
    #cd $build

# create the configure script for we can configure it later
    cat > $build/config.sh << EOF
#!/bin/bash

$REPO_SRC/configure --prefix=$REPO_INST $config
EOF
    chmod +x $build/config.sh
    cd $sdir
}

function deploy_source_prepare() {
    #             github url                                 prefix         branch      commit      config
    item_download "https://github.com/open-mpi/hwloc.git"    "$HWLOC_INST"  ""          "e6559c7"   ""
        HWLOC_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST"> $DEPLOY_DIR/.deploy_repo.lst

    item_download "https://github.com/libevent/libevent.git" "$LIBEV_INST"  ""          "e7ff4ef"   ""
        LIBEV_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst

    item_download "https://github.com/pmix/pmix.git"         "$PMIX_INST"   "v2.0"      ""          "--with-libevent=$LIBEV_INST"
        PMIX_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst

    item_download "https://github.com/openucx/ucx.git"       "$UCX_INST"    ""          ""          ""
        UCX_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst

    item_download "$SLURM_URL"                               "$SLURM_INST"   ""          ""          "--with-ucx=$UCX_INST \
        --with-pmix=$PMIX_INST --with-hwloc=$HWLOC_INST --with-munge=/usr/"
        SLURM_INST=$REPO_INST
        SLURM_SRC=$REPO_SRC
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst

    item_download "https://github.com/open-mpi/ompi.git"     "$OMPI_INST"   "v3.1.x"    ""          "--enable-debug \
        --enable-mpirun-prefix-by-default --with-pmix=$PMIX_INST --with-slurm=$SLURM_INST --with-pmi=$SLURM_INST \
        --with-libevent=$LIBEV_INST --with-ucx=$UCX_INST $OMPI_EXTRA_CONFIG"
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst

    # slurm deploy env prepare
    user=`whoami`
    cat settings.env.in | \
        sed -e "s|\@slurm_src\@|$SLURM_SRC|g" | \
        sed -e "s|\@pmix_install\@|$PMIX_INST|g" | \
        sed -e "s|\@hwloc_install\@|$HWLOC_INST|g" | \
        sed -e "s|\@slurm_install\@|$SLURM_INST|g" | \
        sed -e "s|\@slurm_user\@|$user|g" > settings.env

    if [ -n "$UCX_INST" ]; then
        echo "UCX_INST=$UCX_INST" >> settings.env
    fi

}

function get_item() {
    item_inst=$1
    item=`cat $DEPLOY_DIR/.deploy_repo.lst | grep $item_inst | awk '{print $1}'`
    echo $item
}

function get_repo_item_lst() {
    repo_items=`cat $DEPLOY_DIR/.deploy_repo.lst | awk '{print $2}'`
    echo $repo_items
}

function deploy_build_item() {
    item_inst=$1
	item=`get_item $item_inst`
    light=$2

    sdir=`pwd`
    cd $SRC_DIR/$item
    echo Starting \"$item\" build
    if [ ! -f "configure" ]; then
        if [ -f "autogen.sh" ]; then
            ./autogen.sh || (echo_error $LINENO "$item autogen error" && exit 1)
        else
            ./autogen.pl || (echo_error $LINENO "$item autogen error" && exit 1)
        fi
    fi
    cd .build || (echo_error $LINENO "directory change error" && exit 1)
    if [ ! -f "config.log" ]; then
        ./config.sh || (echo_error $LINENO "$item configure error" && exit 1)
    fi
    make -j $CPU_NUM install || (echo_error $LINENO "$item make error" && exit 1)
    cd $sdir
}

function deploy_build_all() {
    sdir=`pwd`

    if [ ! -f "$DEPLOY_DIR/.deploy_repo.lst" ]; then
        echo "Source code does not ready, please try prepare it by cmd:"
        echo ./`basename "$0"` " source_prepare"
        exit 1
    fi
    repo_list=`get_repo_item_lst`
    if [ -z "$repo_list" ]; then
        echo "Something went wrong. Can not continue."
        exit 1
    fi

    cd $SRC_DIR
    for item_inst in $repo_list; do
		item=`get_item $item_inst`
        if [ -f $item/.build/config.sh ]; then
            deploy_build_item $item_inst
        fi
    done

    slurm_finalize_install

    cd $sdir
}

function deploy_build_clean() {
#    //TODO
    echo deploy_build_clean
}

function deploy_slurm_update_ligth() {
    sdir=`pwd`
    slurm_build_update
    slurm_finalize_install
    slurm_distribute
    cd $sdir
}

function deploy_slurm_pmix_update() {
    sdir=`pwd`
    nodes=`distribute_get_nodes`
    item=`get_item $SLURM_INST`
    cd $SRC_DIR/$item/.build/src/plugins/mpi/pmix
    make -j $CPU_NUM clean
    make -j $CPU_NUM install
    for file in `ls $SLURM_INST/lib/slurm/mpi_pmix*`; do
        copy_remote_nodes $nodes $file $SLURM_INST/lib/slurm/
    done
    cd $sdir

}

function deploy_slurm_update() {
    sdir=`pwd`
    light=$1
    nodes=`distribute_get_nodes`
    deploy_cleanup_item $SLURM_INST
    if [ "$light" == "light" ]; then
        item=`get_item $SLURM_INST`
        cd $SRC_DIR/$item
        make -j $CPU_NUM distclean
        ./config.sh
    fi
    deploy_build_item $SLURM_INST
    deploy_distribute_item $SLURM_INST
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
    nodes=`distribute_get_nodes`
    copy_remote_nodes $nodes $SLURM_INST/etc $SLURM_INST
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

function deploy_distribute_item() {
    item_inst=$1
    nodes=`distribute_get_nodes`
    echo -ne "$nodes: copying $item_inst... "    
    pdir="$(dirname "$item_inst")"
    exec_remote_nodes $nodes mkdir -p $pdir
    copy_remote_nodes $nodes $item_inst $pdir
    echo "OK"
}

function deploy_distribute_all() {
    items_list=`get_repo_item_lst`
    for item_inst in $items_list; do
        deploy_distribute_item $item_inst
    done
}

function deploy_cleanup_item() {
    item_inst=$1
    nodes=`distribute_get_nodes`
    echo -ne "$nodes: removing '$item_inst'... "
    exec_remote_nodes $nodes rm -rf $item_inst
    echo "OK"
}

function deploy_cleanup_all {
    items_list=`get_repo_item_lst`
    for item_inst in $items_list; do
        deploy_cleanup_item $item_inst
    done
}

function deploy_slurm_start() {
    slurm_launch
    slurm_ctl_node=`cat $SLURM_INST/etc/local.conf | grep ControlMachine | cut -f2 -d"="`
    exec_remote_as_user_nodes $slurm_ctl_node $SLURM_INST/sbin/slurmctld
}

function deploy_slurm_stop() {
    slurm_stop_instances
    slurm_ctl_node=`cat $SLURM_INST/etc/local.conf | grep ControlMachine | cut -f2 -d"="`
    exec_remote_as_user_nodes $slurm_ctl_node "$FILES/slurm_kill.sh $SLURM_INST"
}