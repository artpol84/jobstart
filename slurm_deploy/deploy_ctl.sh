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
    mkdir -p $1
    if [ "$?" != "0" ]; then
        echo "Cannot continue"
        exit 1
    fi
}

function check_file() {
    file=$1
    if [ ! -f "$file" ]; then
        echo "File \"$file\" not found. Cannot continue."
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
    else
        if [ -n "$giturl" ]; then
            if [ -n "$branch" ]; then
                git clone --progress -b $branch $giturl $REPO_NAME
            else
                git clone --progress $giturl $REPO_NAME
            fi
            if [ "$?" != "0" ]; then
                echo_error $LINENO "\"$REPO_NAME\" Repository can not be obtained. Cannot continue. "
                exit 1
            fi
        else
            create_dir $SRC_DIR/$REPO_NAME
            curl -L $packurl | tar -xz -C $SRC_DIR/$REPO_NAME --strip-components 1
            if [ "0" -ne "${PIPESTATUS[0]}" ]; then
                echo_error $LINENO "\"$REPO_NAME\" Repository can not be obtained. Cannot continue. "
                rm -rf $SRC_DIR/$REPO_NAME
                exit 1
            fi
        fi
        
        if [ -n "$commit" ]; then
            cd $REPO_SRC
            git checkout -b test $commit
            cd -
        fi
    fi

    if [ "$?" != "0" ]; then
        echo_error $LINENO "\"$REPO_NAME\": Repository can not be prepared. Cannot continue."
        exit 1
    fi

    build=$REPO_NAME/.build
    if [ ! -d "$build" ]; then
        create_dir $build
    fi

    fix_config=`echo "$config " | sed -e 's/--with-[a-z]*= //g'`
    config="--prefix=$REPO_INST $fix_config"

    if [ -n "$config" ]; then
        echo "\"$REPO_NAME\": the following config will be configure : \"$config\""
    fi

    
# create the configure script for we can configure it later
    cat > $build/config.sh << EOF
#!/bin/bash

$REPO_SRC/configure $config
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

    distribute_nodes=`distribute_get_nodes` # nodes on which the software will be distributed
    build_node=`hostname`
    if [ -n "$distribute_nodes" ]; then
        build_node=`scontrol show hostname $distribute_nodes | head -n 1` # get first node for run build on it
    fi

    build_cpus=`ssh $build_node "grep -c ^processor /proc/cpuinfo"`

    cd $SRC_DIR/$item
    echo Starting \"$item\" build

    # add tools path
    tools_installed=`ssh $build_node "test ! -d $INSTALL_DIR/tools/bin"`
    if [ `ssh $build_node test ! -d $INSTALL_DIR/tools/bin; echo $?` ]; then
        tools_path="$INSTALL_DIR/tools/bin"
    fi

    if [ ! -f "configure" ]; then
        rpath=`ssh $build_node 'echo $PATH'`
        if [ -f "autogen.sh" ]; then
            pdsh -S -w $build_node "export PATH=$tools_path:$rpath ; cd $PWD && ./autogen.sh"
        else
            pdsh -S -w $build_node "export PATH=$tools_path:$rpath ; cd $PWD && ./autogen.pl"
        fi
        ret=$?
        if [ "$ret" != "0" ]; then
            echo_error $LINENO "\"$item\" Remote Autogen error. Tries to run Autogen locally..."
            if [ -f "autogen.sh" ]; then
                export PATH=$tools_path:$PATH && ./autogen.sh
            else
                export PATH=$tools_path:$PATH && ./autogen.pl
            fi
        fi
        if [ "$?" != "0" ]; then
            echo_error $LINENO "\"$item\" Autogen error. Cannot continue."
            rm configure 2> /dev/null
            exit 1
        fi
    fi
    cd .build || (echo_error $LINENO "directory change error" && exit 1)
    if [ ! -f "config.log" ]; then
        pdsh -S -w $build_node "cd $PWD && ./config.sh"
        if [ "$?" != "0" ]; then
            echo_error $LINENO "\"$item\" Configure error. Cannot continue."
            mv config.log config.log.bak
            exit 1
        fi
    fi
    if [ ! -f ".deploy_build_flag" ]; then
        pdsh -S -w $build_node "cd $PWD && make -j $build_cpus"
        ret=$?
        if [ "$ret" != "0" ]; then
            echo_error $LINENO "\"$item\" Build error. Cannot continue."
            exit 1
        fi
        echo 1 > .deploy_build_flag
    fi
    pdsh -S -w $build_node "cd $PWD && make -j $build_cpus install"
    ret=$?
    if [ "$?" != "0" ]; then
        echo_error $LINENO "\"$item\" `make install` error. Cannot continue."
        exit 1
    fi

    if [ $item = "slurm" ]; then
         pdsh -S -w $build_node "cd $PWD/contribs/pmi && make -j $build_cpus install"
         pdsh -S -w $build_node "cd $PWD/contribs/pmi2 && make -j $build_cpus install"
    fi

    cd $sdir

    if [ `hostname` != "$build_node" ]; then
        if [ ! -d "$item_inst" ]; then
            create_dir $item_inst
        fi
        scp -r $build_node:$item_inst $INSTALL_DIR
    fi
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
    
    deploy_env_gen
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
    if [ -z "$nodes" ]; then
        echo ""
        return
    fi
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
    echo "Slurm daemons will be stopped before cleaning"
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
    nodes=`distribute_get_nodes`
    exec_remote_nodes $nodes rm -rf $INSTALL_DIR
}

function deploy_cleanup_remote {
    echo "Slurm daemons will be stopped before cleaning"
    deploy_slurm_stop
    
    items_list=`get_repo_item_lst`
    for item_inst in $items_list; do
        deploy_cleanup_item $item_inst
    done
    nodes=`distribute_get_nodes`
    exec_remote_nodes $nodes rm -rf $INSTALL_DIR    
}

function deploy_cleanup_tmp {
    echo "Slurm daemons will be stopped before cleaning"
    deploy_slurm_stop
    nodes=`distribute_get_nodes`
    if [ ! -d "$INSTALL_DIR/slurm" ]; then
        echo_error $LINENO "Error: Slurm installation directory does not exist"
        exit
    fi
    rm -rf $INSTALL_DIR/slurm/tmp/*
    rm -rf $INSTALL_DIR/slurm/var/*
    exec_remote_nodes $nodes rm -rf $INSTALL_DIR/slurm/tmp/*
    exec_remote_nodes $nodes rm -rf $INSTALL_DIR/slurm/var/*
    echo "OK"
}

function deploy_slurm_start() {
    distribute_nodes=`distribute_get_nodes` # nodes on which the software will be distributed
    first_node=`hostname`
    if [ -n "$distribute_nodes" ]; then
        first_node=`scontrol show hostname $distribute_nodes | head -n 1` # get first node for run build on it
    fi
    slurm_ctl_node=`ssh $first_node cat $SLURM_INST/etc/local.conf | grep ControlMachine | cut -f2 -d"="`
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
        
        compute_node=`get_first_node`

        #get CPU params from the compute node
        CPUS=`pdsh -N -w $compute_node nproc`
        THREAD_PER_CORE=`pdsh -N -w $compute_node lscpu | grep -i "Thread(s) per core:" | cut -d":" -f2 | tr -d '[:space:]'`
        CORE_PER_SOCK=`pdsh -N -w $compute_node lscpu | grep -i "Core(s) per socket" | cut -d":" -f2 | tr -d '[:space:]'`
        SOCKETS=`pdsh -N -w $compute_node lscpu | grep -i "Socket(s)" | cut -d":" -f2 | tr -d '[:space:]'`
        CONTROL_MACHINE=`hostname`
        CFG_NODE_LIST=`get_node_list`

        #gnerate a confug file
        cat $FILES/local.conf.in | \
            sed -e "s/@cluster_name@/deploy/g" | \
            sed -e "s/@node_cpus@/$CPUS/g" | \
            sed -e "s/@node_sock_num@/$SOCKETS/g" | \
            sed -e "s/@node_core_per_socket@/$CORE_PER_SOCK/g" | \
            sed -e "s/@node_thread_per_core@/$THREAD_PER_CORE/g" | \
            sed -e "s/@node_list@/$CFG_NODE_LIST/g" | \
            sed -e "s/@partition@/$SLURM_JOB_PARTITION/g" | \
            sed -e "s/@node_ctl@/$CONTROL_MACHINE/g" > $tdir/local.conf

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

function deploy_env_gen() {
    local env_file=$DEPLOY_DIR/deploy_env.sh
    local path=
    local libs=
    items_list=`get_repo_item_lst`
    for item_inst in $items_list; do
        local item_env
        item_env=`cat $DEPLOY_DIR/.deploy_env | grep $item_inst | cut -f2 -d "=" | awk '{print $1}'`
        path=$path:$item_env/bin
        libs=$path:$item_env/lib
    done

    cat > $env_file << EOF
#!/bin/bash

export PATH=$path:$PATH
export LD_LIBRARY_PATH=$libs:$LD_LIBRARY_PATH

EOF
    chmod +x $env_file

    if [ "$?" != "0" ]; then
        echo "Cannot generate env file"
        exit 1
    fi
    echo "The env file was generated to $env_file"
}
