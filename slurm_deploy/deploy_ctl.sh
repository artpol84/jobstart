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

if [ -z "$MUNGE_INST" ];then 
    MUNGE_INST="/usr"
fi

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
    REPO_NAME=$1
    packurl=$2
    giturl=$3
    REPO_INST=$4
    branch=$5
    commit=$6
    config=$7

    REPO_SRC=""
    REPO_INST=""

    sdir=`pwd`

    if [ -z "$giturl" ] && [ -z "$packurl" ]; then
        echo_error $LINENO "source url for \"$REPO_NAME\" was not set, continue..."
        return 0
    fi

    REPO_SRC=$SRC_DIR/$REPO_NAME
    REPO_INST=$INSTALL_DIR/$REPO_NAME

    if [ ! -d "$SRC_DIR" ]; then
        mkdir -p $SRC_DIR
        if [ ! -d $SRC_DIR ]; then
            echo_error $LINENO "source code directory cen not be created"
            exit 1
        fi
    fi
    cd $SRC_DIR

    echo "\"$REPO_NAME\" repository downloading..."
    if [ -d $SRC_DIR/$REPO_NAME ]; then
        echo_error $LINENO "\"$REPO_NAME\" repository already exist, use it. Please delete to download ..."
        return
    else
        if [ -n "$giturl" ]; then
            if [ -n "$branch" ]; then
                git clone --progress -b $branch $giturl $REPO_NAME
            else
                git clone --progress $giturl $REPO_NAME
            fi
        else
            create_dir $SRC_DIR/$REPO_NAME
            curl -L $packurl | tar -xz -C $SRC_DIR/$REPO_NAME --strip-components 1
            if [ "0" -ne "${PIPESTATUS[0]}" ]; then
                echo_error $LINENO "\"$REPO_NAME\" repository can not be obtained"
                rm -rf $SRC_DIR/$REPO_NAME
                exit 1
            fi
        fi
    fi
    cd $REPO_SRC
    if [ -n "$commit" ]; then
        git checkout -b test $commit
    fi
    build=$REPO_SRC/.build
    #rm -rf .build
    if [ ! -d ".build" ]; then
        create_dir .build
    fi
    #cd $build

    fix_config=`echo "$config " | sed -e 's/--with-[a-z]*= //g'`
    config=$fix_config

# create the configure script for we can configure it later
    cat > $build/config.sh << EOF
#!/bin/bash

$REPO_SRC/configure --prefix=$REPO_INST $config
EOF
    chmod +x $build/config.sh
    cd $sdir
}

function deploy_item_reset_env() {
    rm -f $DEPLOY_DIR/.deploy_repo.lst
    rm -f $DEPLOY_DIR/.deploy_env
}

function deploy_item_save_env() {
    repo_name=$1
    repo_inst=$2
    repo_src=$3
    repo_env_prefix=$4

    eval ${repo_env_prefix}_INST=$repo_inst
    eval ${repo_env_prefix}_SRC=$repo_src
   
    if [ -n "$repo_inst" ]; then
        echo "${repo_env_prefix}_INST=$repo_inst # $repo_name install">> $DEPLOY_DIR/.deploy_env
        echo "$repo_name $repo_inst">> $DEPLOY_DIR/.deploy_repo.lst
    fi
    if [ -n "$repo_src" ]; then
        echo "${repo_env_prefix}_SRC=$repo_src # $repo_name source"   >> $DEPLOY_DIR/.deploy_env
    fi
}

function deploy_source_prepare() {
    deploy_item_reset_env
    #             github url                                 prefix         branch      commit      config
    item_download "hwloc" "$HWLOC_PACK" "$HWLOC_URL" "$HWLOC_INST" "$HWLOC_BRANCH" "$HWLOC_COMMIT" "$HWLOC_CONF"
    deploy_item_save_env "$REPO_NAME" "$REPO_INST" "$REPO_SRC" "HWLOC"

    item_download "libevent" "$LIBEV_PACK" "$LIBEV_URL" "$LIBEV_INST" "$LIBEV_BRANCH" "$LIBEV_COMMIT" "$LIBEV_CONF"
    deploy_item_save_env "$REPO_NAME" "$REPO_INST" "$REPO_SRC" "LIBEV"

    item_download "pmix" "$PMIX_PACK" "$PMIX_URL" "$PMIX_INST" "$PMIX_BRANCH" "$PMIX_COMMIT" "$PMIX_CONF --with-libevent=$LIBEV_INST"
    deploy_item_save_env "$REPO_NAME" "$REPO_INST" "$REPO_SRC" "PMIX"

    item_download "ucx" "$UCX_PACK" "$UCX_URL" "$UCX_INST" "$UCX_BRANCH" "$UCX_COMMIT" "$UCX_CONF"
    deploy_item_save_env "$REPO_NAME" "$REPO_INST" "$REPO_SRC" "UCX"

    item_download "slurm" "$SLURM_PACK" "$SLURM_URL" "$SLURM_INST" "$SLURM_BRANCH" "$SLURM_COMMIT" "$SLURM_CONF --with-ucx=$UCX_INST \
 --with-pmix=$PMIX_INST --with-hwloc=$HWLOC_INST --with-munge=$MUNGE_INST"
    deploy_item_save_env "$REPO_NAME" "$REPO_INST" "$REPO_SRC" "SLURM"
    
    item_download "ompi" "$OMPI_PACK" "$OMPI_URL" "$OMPI_INST" "$OMPI_BRANCH" "$OMPI_COMMIT" "$OMPI_CONF \
 --with-pmix=$PMIX_INST --with-slurm=$SLURM_INST --with-pmi=$SLURM_INST \
 --with-libevent=$LIBEV_INST --with-ucx=$UCX_INST --with-hwloc=$HWLOC_INST"
    deploy_item_save_env "$REPO_NAME" "$REPO_INST" "$REPO_SRC" "OMPI"
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

    # add tools path
    if [ -d "$DEPLOY_DIR/tools/build/bin" ]; then
        export PATH=$DEPLOY_DIR/tools/build/bin:$PATH
    fi
    
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
    echo "Slurm daemins will be stopped before cleaning"
    deploy_slurm_stop
    
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
    slurm_ctl_node=`cat $SLURM_INST/etc/local.conf | grep ControlMachine | cut -f2 -d"="`
    exec_remote_as_user_nodes $slurm_ctl_node $SLURM_INST/sbin/slurmctld
    sleep 3
    slurm_launch
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

function deploy_ompi_remove_files() {
    remove_file_list=`cat $1`
    i=0
    for file in $remove_file_list; do
        rm_files=`find $OMPI_INST -name "$file"`
        for rm_file in $rm_files; do
            echo -ne "$rm_file      "
            `rm -f $rm_file`
            if [ "$?" = "0" ]; then
                i=$((i+1))
                echo "removed"
            fi
        done
    done
    echo "Removed $i files"
}
