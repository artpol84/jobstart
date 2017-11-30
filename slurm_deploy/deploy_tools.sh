#!/bin/bash -e

. ./deploy_ctl.conf
. ./deploy_ctl.sh
. ./prepare_lib.sh

M4_URL_BASE="ftp://ftp.gnu.org/gnu/m4"
M4_VER="1.4.17"
M4_NAME=m4-${M4_VER}
M4_DISTR=m4-${M4_VER}."tar.bz2"
M4_URL=${M4_URL_BASE}/$M4_DISTR

AUTOCONF_URL_BASE="ftp://ftp.gnu.org/gnu/autoconf"
AUTOCONF_VER="2.69"
AUTOCONF_NAME=autoconf-${AUTOCONF_VER}
AUTOCONF_DISTR=autoconf-${AUTOCONF_VER}."tar.gz"
AUTOCONF_URL=${AUTOCONF_URL_BASE}/$AUTOCONF_DISTR

AUTOMAKE_URL_BASE="ftp://ftp.gnu.org/gnu/automake"
AUTOMAKE_VER="1.15.1"
AUTOMAKE_NAME=automake-${AUTOMAKE_VER}
AUTOMAKE_DISTR=automake-${AUTOMAKE_VER}."tar.gz"
AUTOMAKE_URL=${AUTOMAKE_URL_BASE}/$AUTOMAKE_DISTR

LIBTOOL_URL_BASE="ftp://ftp.gnu.org/gnu/libtool"
LIBTOOL_VER="2.4.6"
LIBTOOL_NAME=libtool-${LIBTOOL_VER}
LIBTOOL_DISTR=libtool-${LIBTOOL_VER}."tar.gz"
LIBTOOL_URL=${LIBTOOL_URL_BASE}/$LIBTOOL_DISTR

FLEX_URL_BASE="http://sourceforge.net/projects/flex/files"
FLEX_VER="2.5.38"
FLEX_NAME=flex-${FLEX_VER}
FLEX_DISTR=flex-${FLEX_VER}."tar.bz2"
FLEX_URL=${FLEX_URL_BASE}/$FLEX_DISTR/download

BASE_PATH=$DEPLOY_DIR/tools
SRC_PATH=$BASE_PATH/src
DISTR_PATH=$BASE_PATH/distr
PREFIX=$INSTALL_DIR/tools

function tools_download() {
    rm -Rf $DISTR_PATH
    mkdir -p $DISTR_PATH

    wget --no-check-certificate -P $DISTR_PATH $M4_URL
    wget --no-check-certificate -P $DISTR_PATH $AUTOCONF_URL
    wget --no-check-certificate -P $DISTR_PATH $AUTOMAKE_URL
    wget --no-check-certificate -P $DISTR_PATH $LIBTOOL_URL
    wget --no-check-certificate -P $DISTR_PATH $FLEX_URL 
}

function tools_remove() {
    if [ -d $BASE_PATH ]; then
        rm -rf $BASE_PATH
    fi
}

function tools_build() {
    rm -Rf $SRC_PATH $PREFIX
    mkdir -p $SRC_PATH

    distribute_nodes=`distribute_get_nodes` # nodes on which the software will be distributed
    build_node=`hostname`
    if [ -n "$distribute_nodes" ]; then
        build_node=`scontrol show hostname $distribute_nodes | head -n 1` # get first node for run build on it
    fi
    build_cpus=`ssh $build_node "grep -c ^processor /proc/cpuinfo"`

    sdir=`pwd`
    export PATH="$PREFIX/bin/":$PATH
    export LD_LIBRARY_PATH="$PREFIX/bin/":$LD_LIBRARY_PATH

    tar -xjvf $DISTR_PATH/$M4_DISTR -C $SRC_PATH
    cd $SRC_PATH/$M4_NAME
    pdsh -w $build_node "cd $PWD && ./configure --prefix=$PREFIX"
    pdsh -w $build_node "cd $PWD && make"
    pdsh -w $build_node "cd $PWD && make install"

    tar -xzvf $DISTR_PATH/$AUTOCONF_DISTR -C $SRC_PATH
    cd $SRC_PATH/$AUTOCONF_NAME
    pdsh -w $build_node "cd $PWD && ./configure --prefix=$PREFIX"
    pdsh -w $build_node "cd $PWD && make"
    pdsh -w $build_node "cd $PWD && make install"

    rpath=`ssh $build_node 'echo $PATH'`
    tar -xzvf $DISTR_PATH/$AUTOMAKE_DISTR -C $SRC_PATH
    cd $SRC_PATH/$AUTOMAKE_NAME
    pdsh -w $build_node "export PATH=$PREFIX/bin:$rpath ; cd $PWD && ./configure --prefix=$PREFIX"
    pdsh -w $build_node "cd $PWD && make"
    pdsh -w $build_node "cd $PWD && make install"

    tar -xzvf $DISTR_PATH/$LIBTOOL_DISTR -C $SRC_PATH
    cd $SRC_PATH/$LIBTOOL_NAME
    pdsh -w $build_node "cd $PWD && ./configure --prefix=$PREFIX"
    pdsh -w $build_node "cd $PWD &&  make"
    pdsh -w $build_node "cd $PWD && make install"

    tar -xjvf $DISTR_PATH/$FLEX_DISTR -C $SRC_PATH
    cd $SRC_PATH/$FLEX_NAME
    pdsh -w $build_node "cd $PWD && ./configure --prefix=$PREFIX"
    pdsh -w $build_node "cd $PWD && make"
    pdsh -w $build_node "cd $PWD && make install"
    cd $sdir
}