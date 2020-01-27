#!/usr/bin/python

import re

class filterSPMIx:
    HOSTNAME=1
    EARLY_WIREUP_START = 2
    EARLY_WIREUP_THREAD = 3
    WIREUP_CONNECTED = 4

    def __init__(self, flt, cluster, chan, sync):
        self.cl = cluster
        self.ch = chan
        self.sync = sync
        self.send_msg_id = 0
        self.recv_msg_id = 0

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


    def lfilter(self, pline, fid):
        nodeid = int(pline["nodeid"])
        hostname = pline["hostname"]
        ts = self.sync.global_ts(nodeid, hostname, float(pline["timestamp"]))

        if ( fid == self.HOSTNAME ):
            if( pline["logline"].find("Start agent thread") != -1 ):
                print "Set the hostname of nodeid=", nodeid, " to ", pline["hostname"]
                n = self.cl.start(nodeid, hostname, ts)
                return 1

        if ( fid == self.EARLY_WIREUP_START ):
            if( pline["logline"].find("WIREUP/early: start") != -1 ):
                print "Record early wireup beginning on nodeid=", nodeid
                n = self.cl.wireup_start(nodeid, ts)
                return 1

        if ( fid == self.EARLY_WIREUP_THREAD ):
            if( pline["logline"].find("WIREUP/early: complete") != -1 ):
                print "Record early wireup finishing on nodeid=", nodeid
                n = self.cl.wireup_init(nodeid, ts)
                return 1
            elif( pline["logline"].find("WIREUP/early: sending initiation message to nodeids:") != -1 ):
                l1 = pline["logline"].split(":")
                l2 = l1[2].strip().split(" ")
                for dst in l2:
                    self.send_msg_id += 1
                    self.ch.update(nodeid, dst, "send", "completed", self.send_msg_id, 0, ts)
                return 1

        if ( fid == self.WIREUP_CONNECTED ):
            regex_tmp = "\s*WIREUP: Connect to (\d+).*"
            t = re.compile(regex_tmp)
            m = t.match(pline["logline"])
            if( m != None ):
                src = int(m.group(1))
                self.recv_msg_id += 1
                self.ch.update(src, nodeid, "recv", "completed", self.recv_msg_id, 0, ts)
                return 1
        return 0
