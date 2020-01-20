#!/usr/bin/python
# Copyright (c) 2020      Mellanox Technologies, Inc.
#                         All rights reserved.

#Standard modules
import re
import os
import sys
import matplotlib.pyplot as plt
import numpy as np

# Local modules
import lFilter as lf
import clusterResources as cr
import channelMatrix as cm

# Regex to filter related lines
# Example:
# [2020-01-15T04:07:51.707] [6.8] debug:  [(null):0] [1579054071.707138] [mpi_pmix.c:153:p_mpi_hook_slurmstepd_prefork] mpi/pmix:  start
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

wireup_matrix = cr.channelMatrix()
ucx_matrix = cr.channelMatrix()

class baseFilter:
    PSTART = 1
    HOSTNAME=2
    EARLY_WIREUP_START = 3
    EARLY_WIREUP_THREAD = 4
    WIREUP_CONNECTED = 5

    def __init__(self, flt):
        self.send_msg_id = 0
        self.recv_msg_id = 0

        # Plugin startup time
        fields = { "function" : "p_mpi_hook_slurmstepd_prefork" }
        flt.add(fields, self, self.PSTART);

        # Set the hostname for the nodeid
        fields = { "function" : "_agent_thread" }
        flt.add(fields, self, self.HOSTNAME);

        # Record Early Wireup start
        fields = { "function" : "pmixp_server_wireup_early" }
        flt.add(fields, self, self.EARLY_WIREUP_START);

        # Record Early Wireup thread
        fields = { "function" : "_wireup_thread" }
        flt.add(fields, self, self.EARLY_WIREUP_THREAD);

        # Record Early Wireup thread
        fields = { "function" : "pmixp_dconn_connect" }
        flt.add(fields, self, self.WIREUP_CONNECTED);


    def bfilter(self, pline, fid):
        print "pline = ", pline["nodeid"]
        nodeid = int(pline["nodeid"])
        n = getNode(nodeid)
        ts = gt.global_ts(nodeid, float(pline["timestamp"]))
        if (fid == self.PSTART):
            print "Set the start time for nodeid = ", nodeid
            n.progress["start"] = ts
            return 1

        if ( fid == self.HOSTNAME ):
            if( pline["logline"].find("Start agent thread") != -1 ):
                print "Set the hostname of nodeid=", nodeid, " to ", pline["hostname"]
                n.hostname = pline["hostname"]
                return 1

        if ( fid == self.EARLY_WIREUP_START ):
            if( pline["logline"].find("WIREUP/early: start") != -1 ):
                print "Record early wireup beginning on nodeid=", nodeid
                n.progress["ewp_start"] = ts
                return 1

        if ( fid == self.EARLY_WIREUP_THREAD ):
            if( pline["logline"].find("WIREUP/early: complete") != -1 ):
                print "Record early wireup finishing on nodeid=", nodeid
                n.progress["ewp_done"] = ts
                return 1
            elif( pline["logline"].find("WIREUP/early: sending initiation message to nodeids:") != -1 ):
                l1 = pline["logline"].split(":")
                l2 = l1[2].strip().split(" ")
                for dst in l2:
                    self.send_msg_id += 1
                    wireup_matrix.update(nodeid, dst, "send", "completed", self.send_msg_id, 0, ts)
                return 1

        if ( fid == self.WIREUP_CONNECTED ):
            regex_tmp = "\s*WIREUP: Connect to (\d+).*"
            t = re.compile(regex_tmp)
            m = t.match(pline["logline"])
            if( m != None ):
                src = m.group(1)
                msg = cr.message()
                self.recv_msg_id += 1
                wireup_matrix.update(src, nodeid, "recv", "completed", self.recv_msg_id, 0, ts)
                return 1
        return 0


# Database

class ucxFilter:
    def __init__(self, flt):
        # Plugin startup time
        fields = { "function" : "_ucx_send" }
        flt.add(fields, self, 1)
        fields = { "function" : "send_handle" }
        flt.add(fields, self, 1)
        fields = { "function" : "_ucx_progress" }
        flt.add(fields, self, 1)

    def bfilter(self, pline, fid):
        nodeid = int(pline["nodeid"])
        n = getNode(nodeid)
        ts = gt.global_ts(nodeid, float(pline["timestamp"]))
        regex_tmp = ".*UCX:\s*(\S+)\s*\[(\S+)\]\s*nodeid=(\d+),\s*mid=(\d+),\s*size=(\d+)"
        t = re.compile(regex_tmp)
        m = t.match(pline["logline"])
        if( m != None ):
            side = m.group(1)
            mtype = m.group(2)
            peer = int(m.group(3))
            mid = int(m.group(4))
            size = int(m.group(5))
            if (side == "send"):
                src = nodeid
                dst = peer
            elif (side == "recv"):
                src = peer
                dst = nodeid
            else:
                assert (False), ("Unsupported UCX operation type: " + side + "; Only 'recv' and 'send' are supported")
            ucx_matrix.update(src, dst, side, mtype, mid, size, ts)
            return 1
        return 0


# Read input data
assert( len(sys.argv) == 3), "Need directory name"

jobid = float(sys.argv[1])
path = sys.argv[2]

for root, dnames, fnames in os.walk(path):
    break

# 1. If mpisync data is available - initialize it
mpisync_file = "mpisync.out"
gt = cr.globalTime()
if mpisync_file in fnames:
    print "Initialize Global Timings"
    gt.load(root + "/" + mpisync_file)

for root, dnames, fnames in os.walk(path):
    break
print "fnames = ", fnames

flt = lf.lFilter(jobid, regex, fdescr, "function")
uf = ucxFilter(flt)
bf = baseFilter(flt)

data = []
# Read file
for fname in fnames:
    with open(root + "/" + fname, 'r') as f:
        text = f.readlines()
    f.close()
    for l in text:
        flt.apply(l)

ucx_matrix.match()
print ucx_materix.comm_time()

x = ucx_matric.comm_lat()
x = np.array([1, 2, 3, 4, 5])
y = np.power(x, 2) # Effectively y = x**2
e = np.array([1.5, 2.6, 3.7, 4.6, 5.5])

plt.errorbar(x["stat"]["size"], x["stat"]["mean"], x["stat"]["stdev"], linestyle='solid', marker='^')

plt.show()
