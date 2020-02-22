#!/usr/bin/python

import re

class filterUCX:
    def __init__(self, flt, cluster, chan, sync):
        self.sync = sync
        self.ch = chan
        self.cluster = cluster
        fields = { "function" : "_ucx_send" }
        flt.add(fields, self, 1)
        fields = { "function" : "send_handle" }
        flt.add(fields, self, 1)
        fields = { "function" : "_ucx_progress" }
        flt.add(fields, self, 1)

    def lfilter(self, pline, fid):
        nodeid = int(pline["nodeid"])
        n = self.cluster.node(nodeid)
        hostname = pline["hostname"]
        ts = self.sync.global_ts(nodeid, hostname, float(pline["timestamp"]))
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

            self.ch.update(src, dst, side, mtype, mid, size, ts)
            # Ensure that all possible states are covered
            if( "completed" == mtype ):
                mtype = "enqueued"
                if( None == self.ch.get_ts(src, dst, side, mtype, mid) ):
                    self.ch.update(src, dst, side, mtype, mid, size, ts)
            if( (side == "send") and ("enqueued" == mtype) ):
                mtype = "pending"
                if( None == self.ch.get_ts(src, dst, side, mtype, mid) ):
                    self.ch.update(src, dst, side, mtype, mid, size, ts)
            return 1
        return 0
