#!/usr/bin/python
# Copyright (c) 2020      Mellanox Technologies, Inc.
#                         All rights reserved.

#Standard modules
import re
import os
import sys
import argparse
import pickle
import inspect
import matplotlib.pyplot as plt
import numpy as np
from copy import deepcopy
import seaborn as sns

# Local modules
import lFilter as lf
import clusterResources as cr
import channelMatrix as cm
import globalTime as gt
import filterSPMIx as fbase
import filterUCX as fucx
import filterColl as fcoll
import collectives as coll


class globalState:
    def __init__(self):
        self.set = None
        self.cluster = None
        self.sync = None
        self.wireup_mtx = None
        self.ucx_mtx = None
        self.coll = None

state = globalState()

def parse_args():
    global state

    parser = argparse.ArgumentParser(description='Slurm PMIx plugin analytics tool')
    parser.add_argument('-p', '--parse', metavar='dataset', dest='parse_path', help="Parse the dataset located by provided 'dataset' path to the 'analytics-file'")
# TODO: need this in final version
#    parser.add_argument('-g', '--debug', metavar='dataset', dest='debug_path', help="interpret 'dataset' as a directory of Slurmd logs, perform correctness analysis only")
    parser.add_argument('-d', '--display', metavar='mode', dest='display_mode', help="Set display mode: 'summary', 'latency', 'heatmap-bw', 'heatmap-time'.")
    parser.add_argument('-j', '--jobid', metavar='ID', dest='jobid', type=float, help="Specify the Slurm Job ID")
# TODO: need this in final version
#    parser.add_argument('data_file', metavar='analytics_file', help="The file with parsed dataset")
    state.set = parser.parse_args()
    has_parse = (state.set.parse_path != None)
#    has_debug = (s.debug_path != None)
    has_display = (state.set.display_mode != None)

    if( 2 != (has_display + has_parse)) :
        print "parse_args(ERROR): Need parse path and display mode"
        sys.exit(1)
        
#    if( 0 == (has_parse + has_debug + has_display)) :
#        print "parse_args(ERROR): One (and only one) of the following options is required: '--parse', '--debug' and '--display'"
#        sys.exit(1)
#    if( 1 < (has_parse + has_debug + has_display)) :
#        print "parse_args(ERROR): Two or more confliction options '--parse', '--debug' and '--display' were specified together"
#        sys.exit(1)
#
    if( has_parse and (not os.path.isdir(state.set.parse_path))):
        print "parse_args(ERROR): '--parse' directory doesn't exists: ", s.parse_path
        sys.exit(1)
#    if( has_debug and (not os.path.isdir(s.debug_path))):
#        print "parse_args(ERROR): '--debug' directory doesn't exists: ", s.debug_path
#        sys.exit(1)
#    if( has_display and (not os.path.exists(state.set.data_file))):
#        print "parse_args(ERROR): 'analytics_file' doesn't exists: ", s.data_file
#        sys.exit(1)


def parse_slurmd_logs(flt, path):
    if( not os.path.isdir(path)):
        print "parse_slurmd_logs(ERROR): '--parse' directory doesn't exists: ", s.parse_path
        sys.exit(1)

    data = []
    # Read file
    for root, dnames, fnames in os.walk(path, True):
        break
    for fname in fnames:
        with open(path +"/" + fname, 'r') as f:
            text = f.readlines()
        f.close()
        for l in text:
            flt.apply(l)

def discover_jobid(path):
    for root, dnames, fnames in os.walk(path, True):
        if( len(fnames) > 0 ):
            regex="mpi_probe_(\S+)_\S+"
            r = re.compile(regex)
            m = r.match(fnames[0])
            if( None != m):
                return float(m.group(1))
            regex="pmix_probe_(\S+)_\S+"
            r = re.compile(regex)
            m = r.match(fnames[0])
            if( None != m):
                return float(m.group(1))
        break
    return None

def parse_dataset():
    path = state.set.parse_path
    jobid = state.set.jobid

    if( None == jobid ):
        jobid = discover_jobid(path + "/app_logs")
    if( None == jobid ):
        # TODO: extract the jobid from the files
        print "ERROR: Slurm Job ID is required: ", mpisync_path
        sys.exit(1)
        
    # 1. If mpisync data is available - initialize it
    print "Initialize Global Time"
    mpisync_file = "mpisync.out"
    mpisync_path = path + "/" + mpisync_file
    if( not os.path.exists(mpisync_path)):
        print "ERROR: No Time synchronization file (aka mpisync): ", mpisync_path
        sys.exit(1)
    state.sync = gt.globalTime()
    state.sync.load(mpisync_path)

    # 2. Initialize data objects
    state.wireup_mtx = cm.channelMatrix("send", "recv")
    state.ucx_mtx = cm.channelMatrix("send", "recv")
    state.cluster = cr.clusterSystem()
    state.coll = coll.collectives(state.cluster)

    # 3. Initialize The Line filter framework and custom filters
    print "Initialize The Line filter framework and custom filters"
    # Regex to filter related lines
    # Example:
    # [2020-01-15T04:07:51.707] [6.8] debug:  [(null):0] [1579054071.707138] [mpi_pmix.c:153:p_mpi_hook_slurmstepd_prefork] mpi/pmix:  start
    regex_chk = "^\[\S+\]"
    regex = "^\[\S+\] \[(\S+)\]\s*debug:\s*\[(\S+):(\d+)\]\s*\[(\S+)]\s*\[(\S+):(\d+):(\S+)\]\s*mpi/pmix:\s(.*)"
    fdescr = {}
    fdescr["jobid"] = 1
    fdescr["hostname"] = 2
    fdescr["nodeid"] = 3
    fdescr["timestamp"] = 4
    fdescr["file"] = 5
    fdescr["line"] = 6
    fdescr["function"] = 7
    fdescr["logline"] = 8

    flt = lf.lFilter(jobid, regex_chk, regex, fdescr, "function")
    uf = fucx.filterUCX(flt, state.cluster, state.ucx_mtx, state.sync)
    bf = fbase.filterSPMIx(flt, state.cluster, state.wireup_mtx, state.sync)
    cf = fcoll.filterColl(flt, state.cluster, state.coll, state.sync)


    parse_slurmd_logs(flt, path + "/slurm_logs/")
#    state.wireup_mtx.match()
    state.ucx_mtx.match()

def display_msg_lat(ch_matrix):
    x = ch_matrix.comm_lat("enqueued", "completed")
    fig, ax = plt.subplots()
    ax.set_xlabel('Message size (B)')
    ax.set_ylabel('Latency (s)')
    plt.yscale('log')
    ax.tick_params(labelbottom=True, labeltop=True, labelleft=True, labelright=True,
                   bottom=True, top=True, left=True, right=True)
    plt.rcParams.update({'errorbar.capsize': 2})

#    print "X = ", x["data"].keys()
    print  x["stat"]

    plt.errorbar(x["stat"]["size"], x["stat"]["mean"], x["stat"]["stdev"],  linestyle='None', marker='.')
    plt.show()

settings = parse_args()

#if( state.set.parse_path != None ):
#    parse_dataset()
#    serialize()
#elif ( state.set.debug_path != None ):
#    debug_dataset()
#    serialize()
#elif ( state.set.display_mode != None):
if ( state.set.display_mode != None):
    parse_dataset()
    if( "summary" == state.set.display_mode ):
        state.cluster.summary()
        state.coll.summary()
        state.coll.dump("ring", 0)
        state.coll.dump("ring", 3)
    elif( "latency" == state.set.display_mode ):
        display_msg_lat(state.ucx_mtx)
    elif ("heatmap-bw" ==  state.set.display_mode):
        ctime, csize = state.ucx_mtx.comm_time("pending", "completed")

        cbw = deepcopy(csize)
        for src in xrange(0, len(ctime)):
            for dst in xrange(0, len(ctime[src])):
                if( 0 != cbw[src][dst]):
                    cbw[src][dst] = cbw[src][dst] / ctime[src][dst]
        sns.heatmap(cbw, cmap="YlGnBu")
        plt.show()
    elif ("heatmap-tm" ==  state.set.display_mode):
        ctime, csize = state.ucx_mtx.comm_time("pending", "completed")
        # Draw the heatmap with the mask and correct aspect ratio
        print ctime
        sns.heatmap(ctime, cmap="YlGnBu")
        plt.show()

