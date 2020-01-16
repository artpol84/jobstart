#!/usr/bin/python

import datetime
import re
import lFilter as lf
import os
import sys

# Database structures


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

def body_all(obj, body):
    return 1

def body_strstr(obj, body):
    return ( body.find(obj) != -1 )

def action_dummy(obj, pline):
    print "Action Dummy invoked", obj
    return 0

flt = lf.lFilter(6.8, regex, fdescr, "function")

class message:
    def __init__(self):
        self._size = 0
        self._mid = -1
        self.ts = { }

    def set_size(self, size):
        self._size = size
    def size(self):
        return self._size

    def set_mid(self, mid):
        self._mid = mid
    def mid(self):
        return self._mid

    def in_state(self, side, state):
        if( not (side in self.ts.keys())):
            self.ts[side] = { }
        return (state in self.ts[side].keys())

    def dump_states(self, side):
        states = ""
        if( not (side in self.ts.keys())):
            self.ts[side] = { }
        for state in self.ts[side].keys():
            states += state + ", "
        return states

    def set_ts(self, side, state, ts):
        assert (not self.in_state(side, state)), "ERROR: Double message state initialization"
        self.ts[side][state] = ts

class channel:
    def __init__(self):
        self.ch = { }
        self.ch["send"] = { }
        self.ch["recv"] = { }
        self.fifo = { }
        self.fifo["send"] = []
        self.fifo["recv"] = []

    def update(self, side, mid, mtype, size, ts):
        if( not (mid in self.ch[side].keys())):
            msg = message()
            msg.set_size(size)
            msg.set_mid(mid)
            self.ch[side][mid] = msg
            self.fifo[side].append(msg)
        msg = self.ch[side][mid]
        assert (self.ch[side][mid].size() == size), "Message size mismatch"
        msg.set_ts(side, mtype, ts)

    def match(self):
        l = min(len(self.fifo["send"]), len(self.fifo["recv"]))
        for i in xrange(0, l):
            print "Match message #", i
            smsg = self.fifo["send"][i]
            rmsg = self.fifo["recv"][i]
            if (smsg.size() != rmsg.size()):
                ret = "Matching ERROR: message #" + str(i) + ": size: send=" + str(smsg.size()) + " recv=" + str(rmsg.size())
                return ret
            if (not smsg.in_state("send", "completed")):
                ret = "Matching ERROR: message #" + str(i) + ": send is not completed: " + smsg.dump_states("send")
                return ret
            if (not rmsg.in_state("recv", "completed")):
                ret = "Matching ERROR: message #" + str(i) + ": recv is not completed: " + rmsg.dump_states("recv")
                return ret
        if ( len(self.fifo["send"]) != len(self.fifo["recv"]) ):
            ret = "Matching ERROR: mismatch in # of send and recv messages: send=" + str( len(self.fifo["send"]) ) + " recv=" + str( len(self.fifo["recv"]) )
            return ret
        return None


class channelMatrix:
    def __init__(self):
        self.matrix = { }
    def update(self, src, dst, side, mtype, mid, size, ts):
        if( not (src in self.matrix.keys())):
            self.matrix[src] = { }
        if( not (dst in self.matrix[src].keys())):
            self.matrix[src][dst] = channel()
        self.matrix[src][dst].update(side, mid, mtype, size, ts)

    def match(self):
        print "src keys: ", self.matrix.keys()
        for src in self.matrix.keys():
            print "dst keys: ", self.matrix[src].keys()
            for dst in self.matrix[src].keys():
                print "src = ", src, " dst = ", dst
                err = self.matrix[src][dst].match()
                if( err != None):
                    print "(", str(src) + ",", str(dst), "): ", err

    def analysis(self):
        # Verify message send/recv matching
        self.match()

wireup_matrix = channelMatrix()
ucx_matrix = channelMatrix()

class clusterNode:
    def __init__(self, nodeid):
        self.nodeid = nodeid
        self.hostname = ""
        self.progress = { }
        self.wireup = channel()
        self.ucxcomm = channel()

nodeList = { }
def getNode(nodeid):
    if( not (nodeid in nodeList.keys())):
        nodeList[nodeid] = clusterNode(nodeid)
    return nodeList[nodeid]

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
        ts = float(pline["timestamp"])
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
                msg = message()
                self.recv_msg_id += 1
                wireup_matrix.update(src, nodeid, "recv", "completed", self.recv_msg_id, 0, ts)
                return 1
        return 0

bf = baseFilter(flt)

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
        ts = float(pline["timestamp"])
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

uf = ucxFilter(flt)

# Read input data
assert( len(sys.argv) == 2), "Need directory name"
path = sys.argv[1]

root, dnames, fnames = os.walk(path):

data = []
# Read file
for fname in fnames:
    with open(fname, 'r') as f:
        text = f.readlines()
    f.close()
    for l in text:
        flt.apply(l)

ucx_matrix.match()