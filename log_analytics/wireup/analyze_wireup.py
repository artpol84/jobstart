#!/usr/bin/python

import datetime
import re
import lFilter as lf

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
        self._src = -1
        self._dst = -1
        self._size = 0
        self.ts = { }
        self.ts["send"] = { }
        self.ts["recv"] = { }

    def dst(self, peer):
        self._dst = peer
    def dst(self):
        return self._dst

    def src(self, peer):
        self._src = peer
    def src(self):
        return self._src

    def size(self, size):
        self._size = size
    def size(self):
        return self._size

    def set_ts(self, dir, state, ts):
        self.ts[dir][status] = ts

    def in_state(self, dir, state):
        return (state in self.ts[dir].keys())

class channel:
    def __init__(self)
        channel = { }
        channel["send"] = { }
        channel["recv"] = { }

    def enqueue(dir, msg)
        if( not (msg.dst in channel[dir].keys())):
            channel[dir] = []
        channel[dir].append(msg)

    def get_next(dir, dst, state):
        if( not (dst in channel[dir].keys())):
            return None
        for i in channel[dir][dst]:
            if (not msg.in_state(dir, state)) :
                return msg
        return None


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
        if (fid == self.PSTART):
            print "Set the start time for nodeid = ", nodeid
            n.progress["start"] = pline["timestamp"]
            return 1

        if ( fid == self.HOSTNAME ):
            if( pline["logline"].find("Start agent thread") != -1 ):
                print "Set the hostname of nodeid=", nodeid, " to ", pline["hostname"]
                n.hostname = pline["hostname"]
                return 1

        if ( fid == self.EARLY_WIREUP_START ):
            if( pline["logline"].find("WIREUP/early: start") != -1 ):
                print "Record early wireup beginning on nodeid=", nodeid
                n.progress["ewp_start"] = pline["timestamp"]
                return 1

        if ( fid == self.EARLY_WIREUP_THREAD ):
            if( pline["logline"].find("WIREUP/early: complete") != -1 ):
                print "Record early wireup finishing on nodeid=", nodeid
                n.progress["ewp_done"] = pline["timestamp"]
                return 1
            elif( pline["logline"].find("WIREUP/early: sending initiation message to nodeids:") != -1 ):
                l1 = pline["logline"].split(":")
                l2 = l1[2].strip().split(" ")
                for dst in l2:
                    msg = message()
                    msg.dst(dst)
                    msg.set_ts("send", "completed",  pline["timestamp"])
                    n.wireup.enqueue("send", msg)
                return 1

        if ( fid == self.WIREUP_CONNECTED ):
            regex_tmp = "\s*WIREUP: Connect to (\d+).*"
            t = re.compile(regex_tmp)
            m = t.match(pline["logline"])
            if( m != None ):
                src = m.group(1)
                msg = message()
                msg.sc(src)
                msg.set_ts("recv", "complete", pline["timestamp"])
                n.wireup.enqueue("recv", msg)
                print "nodeid=", nodeid, " connected to ", src
                return 1

        return 0

    def action(obj, pline):
        obj._action(pline)
    progress = { }

bf = baseFilter(flt)

# Database

        PMIXP_DEBUG("UCX: send [pending] to nodeid=%d, size=%zu",
                priv->nodeid, msize);
        pmixp_rlist_enq(&priv->pending, msg);
    } else {
        pmixp_ucx_req_t *req = NULL;
        xassert(_direct_hdr_set);
        char *mptr = _direct_hdr.buf_ptr(msg);
        req = (pmixp_ucx_req_t*)
            ucp_tag_send_nb(priv->server_ep,
                    (void*)mptr, msize,
                    ucp_dt_make_contig(1),
                    pmixp_info_nodeid(), send_handle);
        if (UCS_PTR_IS_ERR(req)) {
            PMIXP_ERROR("Unable to send UCX message: %s\n",
                    ucs_status_string(UCS_PTR_STATUS(req)));
            goto exit;
        } else if (UCS_OK == UCS_PTR_STATUS(req)) {
            /* defer release until we unlock ucp worker */
            PMIXP_DEBUG("UCX: send [inline] to nodeid=%d, size=%zu",
                    priv->nodeid, msize);
            release = true;
        } else {
            PMIXP_DEBUG("UCX: send [regular] to nodeid=%d, size=%zu",

class ucxFilter:
    SEND = 1
    COMPLETE = 2

    def __init__(self, flt):
        # Plugin startup time
        fields = { "function" : "_ucx_send" }
        flt.add(fields, self, self.SEND);

    def bfilter(self, pline, fid):
        nodeid = int(pline["nodeid"])
        n = getNode(nodeid)
        if (fid == self.SEND):
            ts = float(pline["timestamp"]
            regex_tmp = ".*UCX: send [(\S+)] to nodeid=(\d+), size=(\d+)"
            t = re.compile(regex_tmp)
            m = t.match(pline["logline"])
            if( m != None ):
                dst = m.group(2)
                mtype = m.group(1)
                size = m.group(3)
                msg = n.ucxcomm.get_next("send", dst, mtype)
                if (msg == None):
                    msg = message()
                    msg.dst(dst)
                    msg.size(size)
                    msg.set_ts("send", mtype, ts)
                    n.ucxcomm.enqueue("send", msg)
                else:
                    assert (msg.size() == size) "The assumption of sequential message processing doesn't hold"
                    assert (!msg.in_state("send", mtype)) "Double state transition"
                    


                msg.size(m.group(3))

                msg = message()
                
                
                msg.send_pending(dst, ts)
                if (mtype == "regular" or mtype == "inline"):
                    msg.send_enq(ts)
                if (mtype == "inline"):
                    msg.send_complete(ts)
                n.
            return 1

        if ( fid == self.HOSTNAME ):
            if( pline["logline"].find("Start agent thread") != -1 ):
                print "Set the hostname of nodeid=", nodeid, " to ", pline["hostname"]
                n.hostname = pline["hostname"]
                return 1

        if ( fid == self.EARLY_WIREUP_START ):
            if( pline["logline"].find("WIREUP/early: start") != -1 ):
                print "Record early wireup beginning on nodeid=", nodeid
                n.progress["ewp_start"] = pline["timestamp"]
                return 1

        if ( fid == self.EARLY_WIREUP_THREAD ):
            if( pline["logline"].find("WIREUP/early: complete") != -1 ):
                print "Record early wireup finishing on nodeid=", nodeid
                n.progress["ewp_done"] = pline["timestamp"]
                return 1
            elif( pline["logline"].find("WIREUP/early: sending initiation message to nodeids:") != -1 ):
                l1 = pline["logline"].split(":")
                l2 = l1[2].strip().split(" ")
                for dst in l2:
                    msg = message()
                    msg.send(dst, pline["timestamp"])
                    n.wireup["out"].append(msg)
                return 1

        if ( fid == self.WIREUP_CONNECTED ):
            regex_tmp = "\s*WIREUP: Connect to (\d+).*"
            t = re.compile(regex_tmp)
            m = t.match(pline["logline"])
            if( m != None ):
                src = m.group(1)
                msg = message()
                msg.recv(src, pline["timestamp"])
                n.wireup["in"].append(msg)
                print "nodeid=", nodeid, " connected to ", src
                return 1

        return 0

    def action(obj, pline):
        obj._action(pline)
    progress = { }





str="[2020-01-15T04:07:51.707] [6.8] debug:  [(null):0] [1579054071.707138] [mpi_pmix.c:153:p_mpi_hook_slurmstepd_prefork] mpi/pmix:  start"
print("filter:", flt.apply(str))

str="[2020-01-15T04:07:51.933] [6.8] debug:  [clx-hercules-004:0] [1579054071.933820] [pmixp_agent.c:227:_agent_thread] mpi/pmix:  Start agent thread"
print("filter:", flt.apply(str))

str="[2020-01-15T04:07:51.934] [6.8] debug:  [clx-hercules-004:0] [1579054071.934096] [pmixp_server.c:1323:_wireup_thread] mpi/pmix:  WIREUP/early: sending initiation message to nodeids: 1 "
print("filter:", flt.apply(str))

str="[2020-01-15T04:07:51.935] [6.8] debug:  [clx-hercules-004:0] [1579054071.935396] [pmixp_server.c:1330:_wireup_thread] mpi/pmix:  WIREUP/early: complete"
print("filter:", flt.apply(str))

str="[2020-01-15T04:07:52.011] [6.8] debug:  [clx-hercules-005:1] [1579054072.011693] [pmixp_dconn.h:228:pmixp_dconn_connect] mpi/pmix:  WIREUP: Connect to 2"
print("filter:", flt.apply(str))
