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

. ./settings.env

FILES=`pwd`/files

function echo_error()
{
    lno=$1
    fl=`basename $0`
    echo "$fl:$lno: $2"
}

function sanity_check()
{
#    tmp=`echo $SLURM_INST | grep ^"/tmp/"`
    tmp=`echo $SLURM_INST`
    local sanity_error=""
    if  [ -z "$tmp" ]; then
        sanity_error=1
    fi
    echo $sanity_error
}

function escape_path()
{
    echo $1 | sed -e 's/\//\\\//g'
}

function slurm_prepare_conf()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi

    mkdir -p $SLURM_INST/etc/
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

    SLURM_INST_ESC=`escape_path $SLURM_INST`
    cat $FILES/slurm.conf.in | \
        sed -e "s/@SLURM_INST@/$SLURM_INST_ESC/g" | \
        sed -e "s/@SLURM_USER@/$SLURM_USER/g" > $SLURM_INST/etc/slurm.conf
}

function slurm_finalize_install()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    #slurm_prepare_conf
    mkdir -p $SLURM_INST/var
    mkdir -p $SLURM_INST/tmp
}

function slurm_build_all(){
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    local sdir=`pwd`
    local tdir=./.build_tmp
    rm -Rf $tdir
    mkdir -p $tdir

    local hwloc_append=""
    if [ -n "$HWLOC_INST" ]; then
        hwloc_append="--with-hwloc=$HWLOC_INST"
    fi
    local ucx_append=""
    if [ -n "$UCX_INST" ]; then
        ucx_append="--with-ucx=$UCX_INST"
    fi

    cd $tdir
    $SLURM_SRC/configure --prefix=$SLURM_INST --with-munge=/usr/ --with-pmix=$PMIX_INST $hwloc_append $ucx_append
    make -j 20
    make -j 20 install

    cd $sdir
}

function slurm_build_remove() {
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    if [ -d "$SLURM_SRC/.build_tmp" ]; then
        rm -rf $SLURM_SRC/.build_tmp
    fi
}

function slurm_build_update() {
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    if [ -d "$SLURM_SRC/.build_tmp" ]; then
        sdir=`pwd`
        cd $SLURM_SRC/.build_tmp
        make -j20 clean
        make -j20
        make -j20 install
        cd $sdir
    fi
}

function slurm_build_update_light() {
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    if [ -d "$SLURM_SRC/.build_tmp" ]; then
        sdir=`pwd`
        cd $SLURM_SRC/.build_tmp
        make -j20
        make -j20 install
        cd $sdir
    fi
}


function slurm_build_plugin()
{
    local sdir=`pwd`
    local tdir=./.build_tmp-$1
    rm -Rf $tdir
    mkdir -p $tdir

    cd $tdir
    eval _pmix_inst=\$PMIX_INST_$1
    $SLURM_SRC/configure --prefix=$SLURM_INST --with-munge=/usr/ --with-pmix=${_pmix_inst}
    cd src/plugins/mpi/pmix/
    make install

    cd $sdir
}

function slurm_build()
{
    slurm_build_all
    for i in `seq 2 10`; do
        eval var=\$PMIX_INST_$i
        if [ -n "$var" ]; then
            slurm_build_plugin $i
        fi
    done
}

function get_node_list()
{
    nodes=$SLURM_JOB_NODELIST
    if [ -z "$nodes" ]; then
        nodes="$NODE_LIST"
    fi

    if [ -z "$nodes" ]; then
        echo_error $LINENO "distribute_slurm: No information about nodes found"
        exit 1
    fi
    echo "$nodes"
}

function exec_remote_nodes()
{
    nodes=$1
    shift
    pdsh_bin=`which pdsh`
    $pdsh_bin -w $nodes $@
}

function exec_remote()
{
    exec_remote_nodes $1
}

function exec_remote_as_user_nodes()
{
    nodes=$1
    shift
    pdsh_bin=`which pdsh`
    if [ `whoami` != "$SLURM_USER" ]; then
        sudo su - $SLURM_USER -c "$pdsh_bin -w $nodes $@"
    else
        $pdsh_bin -w $nodes $@
    fi
}

function exec_remote_as_user()
{
    nodes=`get_node_list`
    exec_remote_as_user_nodes $nodes $@
}

function copy_remote_nodes()
{
    nodes=$1
    pdcp_bin=`which pdcp`
    $pdcp_bin -w $nodes -r $2 $3
}

function copy_remote()
{
    copy_remote_nodes $nodes $1 $2
}

function slurm_stop_instances()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    exec_remote_as_user "$FILES/slurm_kill.sh $SLURM_INST"
}

function slurm_cleanup_installation_nodes()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    # stop all running processes
    slurm_stop_instances

    # get back the rights on the files
    if [ `whoami` != "$SLURM_USER" ]; then
        exec_remote_nodes $1 sudo chown -R `whoami` $SLURM_INST
    fi

    # Remove the files
    exec_remote_nodes $1 rm -Rf --preserve-root $SLURM_INST
}

function slurm_cleanup_installation()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    nodes=`get_node_list`
    slurm_cleanup_installation_nodes $nodes
}

function node_is_head()
{
    nodes=`get_node_list`
    head_node=`scontrol show hostname $nodes | grep \`hostname\``
    echo $head_node
}
function get_node_list_wo_head()
{
    nodes=`get_node_list`
    nodes_wo_head_str=`scontrol show hostname $nodes | grep -v \`hostname\` | paste -d, -s`
    nodes_wo_head=`scontrol show hostlist $nodes_wo_head_str`
    echo $nodes_wo_head
}

function slurm_distribute()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    nodes=`get_node_list`

    head_node=`node_is_head`
    if [ ! -z $head_node ]; then
        nodes=`get_node_list_wo_head`
        # Cleanup previous installations
        slurm_cleanup_installation_nodes $nodes $SLURM_INST
    else
        # Cleanup previous installations
        slurm_cleanup_installation $SLURM_INST
    fi

    # Prepare the FS
    base_dir=`dirname $SLURM_INST`
    exec_remote_nodes $nodes mkdir -p $SLURM_INST
    
    # Copy & fix the installation files
    copy_remote_nodes $nodes $SLURM_INST/bin $SLURM_INST
    copy_remote_nodes $nodes $SLURM_INST/etc $SLURM_INST
    copy_remote_nodes $nodes $SLURM_INST/include $SLURM_INST
    copy_remote_nodes $nodes $SLURM_INST/lib $SLURM_INST
    copy_remote_nodes $nodes $SLURM_INST/sbin $SLURM_INST
    copy_remote_nodes $nodes $SLURM_INST/share $SLURM_INST
    exec_remote_nodes $nodes mkdir "$SLURM_INST/var/"
    exec_remote_nodes $nodes mkdir "$SLURM_INST/tmp/"

    # Give up rights on this directory to the SLURM user
    if [ `whoami` != "$SLURM_USER" ]; then
        exec_remote_nodes $nodes sudo chown -R $SLURM_USER $SLURM_INST
    fi
}

function slurm_launch()
{
    if [ -n "`sanity_check`" ]; then
        echo_error $LINENO "Error sanity check"
        exit 1
    fi
    nodes=`get_node_list`
    # launch as SLURM USER
    exec_remote_as_user_nodes $nodes "$FILES/slurm_launch.sh $SLURM_INST"
}
