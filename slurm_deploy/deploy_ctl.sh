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

if [ -f $DEPLOY_DIR/.deploy_env ]; then
    . $DEPLOY_DIR/.deploy_env
fi

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
    repo_name=$1
    packurl=$2
    giturl=$3
    REPO_INST=$4
    branch=$5
    commit=$6
    config=$7

    sdir=`pwd`

    if [ -z "$giturl" ] && [ -z "$packurl" ]; then
        echo_error $LINENO "source url was not set"
    fi
    if [ ! -d "$SRC_DIR" ]; then
        mkdir -p $SRC_DIR
        if [ ! -d $SRC_DIR ]; then
            echo_error $LINENO "source code directory cen not be created"
            exit 1
        fi
    fi
    cd $SRC_DIR

    echo "\"$repo_name\" repository downloading..."
    if [ -d $SRC_DIR/$repo_name ]; then
        echo_error $LINENO "\"$repo_name\" repository already exist, continue..."
    else
        if [ -n "$giturl" ]; then
            if [ -n "$branch" ]; then
                git clone --progress -b $branch $giturl 2>&1 | tee -a $tmp
            else
                git clone --progress $giturl 2>&1 | tee -a $tmp
            fi
        else
            create_dir $SRC_DIR/$repo_name
            curl -L $packurl | tar -xz -C $SRC_DIR/$repo_name --strip-components 1
            if [ "0" -ne "${PIPESTATUS[0]}" ]; then
                echo_error $LINENO "\"$repo_name\" repository can not be obtained"
                rm -rf $SRC_DIR/$repo_name
                exit 1
            fi
        fi
    fi
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
    item_download "hwloc" "$HWLOC_PACK" "$HWLOC_URL" "$HWLOC_INST" "$HWLOC_BRANCH" "$HWLOC_COMMIT" "$HWLOC_CONF"
        HWLOC_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST"> $DEPLOY_DIR/.deploy_repo.lst
        echo "HWLOC_INST=$REPO_INST # $REPO_NAME"> $DEPLOY_DIR/.deploy_env

    item_download "libevent" "$LIBEV_PACK" "$LIBEV_URL" "$LIBEV_INST" "$LIBEV_BRANCH" "$LIBEV_COMMIT" "$LIBEV_CONF"
        LIBEV_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst
        echo "LIBENV_INST=$REPO_INST # $REPO_NAME">> $DEPLOY_DIR/.deploy_env

    item_download "pmix" "$PMIX_PACK" "$PMIX_URL" "$PMIX_INST" "$PMIX_BRANCH" "$PMIX_COMMIT" "$PMIX_CONF --with-libevent=$LIBEV_INST"
        PMIX_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst
        echo "PMIX_INST=$REPO_INST # $REPO_NAME">> $DEPLOY_DIR/.deploy_env

    item_download "ucx" "$UCX_PACK" "$UCX_URL" "$UCX_INST" "$UCX_BRANCH" "$UCX_COMMIT" "$UCX_CONF"
        UCX_INST=$REPO_INST
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst
        echo "UCX_INST=$REPO_INST # $REPO_NAME">> $DEPLOY_DIR/.deploy_env

    item_download "slurm" "$SLURM_PACK" "$SLURM_URL" "$SLURM_INST" "$SLURM_BRANCH" "$SLURM_COMMIT" "$SLURM_CONF --with-ucx=$UCX_INST \
        --with-pmix=$PMIX_INST --with-hwloc=$HWLOC_INST --with-munge=/usr/"
        SLURM_INST=$REPO_INST
        SLURM_SRC=$REPO_SRC
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst
        echo "SLURM_INST=$REPO_INST # $REPO_NAME">> $DEPLOY_DIR/.deploy_env
        echo "SLURM_SRC=$REPO_SRC">> $DEPLOY_DIR/.deploy_env

    item_download "ompi" "$OMPI_PACK" "$OMPI_URL" "$OMPI_INST" "$OMPI_BRANCH" "$OMPI_COMMIT" "$OMPI_CONF \
        --with-pmix=$PMIX_INST --with-slurm=$SLURM_INST --with-pmi=$SLURM_INST \
        --with-libevent=$LIBEV_INST --with-ucx=$UCX_INST --with-hwloc=$HWLOC_INST"
        echo "$REPO_NAME $REPO_INST">> $DEPLOY_DIR/.deploy_repo.lst
        echo "OMPI_INST=$REPO_INST # $REPO_NAME">> $DEPLOY_DIR/.deploy_env
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
    if [ -d "$INSTALL_DIR" ]; then
        if [ -n "`sanity_check`" ]; then
            echo_error $LINENO "Error sanity check"
            exit 1
        fi
        rm -rf $INSTALL_DIR
    fi
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

function slurm_prepare_conf()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi

    slurm_conf=$1

    mkdir -p $SLURM_INST/etc/

    if [ -n "$slurm_conf" ]; then
        if [ ! -f $slurm_conf ]; then
            echo_error $LINENO "Can not set Slurm config file: file does not exist"
            exit 1
        fi
        echo "Use config $slurm_conf"
        cp -f $slurm_conf $SLURM_INST/etc/local.conf
    else
        local tdir=./.conf_tmp

        rm -fR $tdir
        mkdir $tdir
        # Remove unneeded portions
        cat /etc/slurm/local.conf | grep -v "ControlMachine" | \
            grep -v "BackupController" | \
            grep -v "local_dbd" | \
            grep -v "TopologyPlugin" | \
            sed -e "s/AllocNodes=[a-z,0-9\-]*/AllocNodes=`hostname`/g" | \
            sed -e "s/RealMemory=[0-9]* //g" >  $tdir/local.conf

        echo >> $tdir/local.conf
        echo "ControlMachine=`hostname`" >> $tdir/local.conf
        cp $tdir/local.conf $SLURM_INST/etc/
        rm -fR $tdir
    fi

    SLURM_INST_ESC=`escape_path $SLURM_INST`
    cat $FILES/slurm.conf.in | \
        sed -e "s/@SLURM_INST@/$SLURM_INST_ESC/g" | \
        sed -e "s/@SLURM_USER@/$SLURM_USER/g" > $SLURM_INST/etc/slurm.conf

    nodes=`distribute_get_nodes`
    copy_remote_nodes $nodes $SLURM_INST/etc $SLURM_INST
}

