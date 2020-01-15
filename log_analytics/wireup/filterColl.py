#!/usr/bin/python

import re

class filterColl:
    RING_LOCAL = 1
    RING_REMOTE = 2
    RING_FORWARD = 3

    def __init__(self, flt, cluster, coll, sync):
        self.cl = cluster
        self.coll = coll
        self.sync = sync


        # ================== Ring collective ===============================
        # Local contribution
        # Ring: [2020-01-27T00:22:31.463] [2.21] debug:  [clx-hercules-022:0] [1580077351.463375] [pmixp_coll_ring.c:591:pmixp_coll_ring_local] mpi/pmix:  0x956d00: ctx=0x956de8, contrib/loc: collseq=0, state=1, contrib=0, size=642
        fields = { "function" : "pmixp_coll_ring_local" }
        flt.add(fields, self, self.RING_LOCAL);
        regex = "\s(0x[0-9a-fA-F]+):\sctx=(0x[0-9a-fA-F]+),\scontrib/loc:\scollseq=(\d+),\sstate=(\d+),\scontrib=(\d+),\ssize=(\d+)"
        self.ring_local_regex = re.compile(regex)

        # Remote contribution
        # [2020-01-26T23:50:56.112] [2.5] debug:  [clx-hercules-022:0] [1580075456.112417] [pmixp_coll_ring.c:665:pmixp_coll_ring_neighbor] mpi/pmix:  0x956c80: ctx=0x956d68 contrib/nbr: collseq=0, state=0, nodeid=7, contrib=6, hopseq=1, size=604
        fields = { "function" : "pmixp_coll_ring_neighbor" }
        flt.add(fields, self, self.RING_REMOTE);
        regex = "\s(0x[0-9a-fA-F]+):\sctx=(0x[0-9a-fA-F]+)\scontrib/nbr:\scollseq=(\d+),\sstate=(\S+),\snodeid=(\d+),\scontrib=(\d+),\shopseq=(\d+),\ssize=(\d+)"
        self.ring_remote_regex = re.compile(regex)

        # Forward to the next neighbor
        # [2020-01-27T00:22:31.463] [2.21] debug:  [clx-hercules-022:0] [1580077351.463388] [pmixp_coll_ring.c:266:_ring_forward_data] mpi/pmix:  0x956d00: ctx=0x956de8 transit to nodeid=1, collseq=0, hopseq=0, size=642, contrib_id=0
#        fields = { "function" : "_ring_forward_data" }
#        flt.add(fields, self, self.RING_FORWARD);
#        regex = "\s(0x[0-9a-fA-F]+):\sctx=(0x[0-9a-fA-F]+)\stransit to\snodeid=(\d+)\scollseq=(\d+)\s,\shopseq=(\d+),\ssize=(\d+),\scontrib=(\d+)"
#        self.ring_fwd_regex = re.compile(regex)


        # ================== Tree collective ===============================

        # Tree: [2020-01-17T08:29:30.515] [3.18] debug:  [clx-hercules-088:0] [1579242570.515488] [pmixp_coll_tree.c:906:pmixp_coll_tree_local] mpi/pmix:  0x9a8710: contrib/loc: seqnum=0, state=COLL_SYNC, size=19
#        fields = { "pmixp_coll_tree_local" : "contrib/loc" }
#        flt.add(fields, self, self.LOCAL_CONTRIB_TREE);


    def lfilter(self, pline, fid):
#        print "COLLECTIVES: pline = ", pline
        nodeid = int(pline["nodeid"])
        n = self.cl.node(nodeid)
        hostname = pline["hostname"]
        ts = self.sync.global_ts(nodeid, hostname, float(pline["timestamp"]))

        if ( fid == self.RING_LOCAL ):
            m = self.ring_local_regex.match(pline["logline"])
            if( m != None ):
                cptr = int(m.group(1), 16)
                ctxptr = int(m.group(2), 16)
                cseq = int(m.group(3))
                state = int(m.group(4))
                contrib_id = int(m.group(5))
                size = int(m.group(6))
                self.coll.update("ring", cseq, contrib_id, size, ts, nodeid)
#                print "COLLECTIVES: Append local contrib: " + pline["logline"]
                return 1

        if ( fid == self.RING_REMOTE ):
            m = self.ring_remote_regex.match(pline["logline"])
            if( m != None ):
                cptr = int(m.group(1), 16)
                ctxptr = int(m.group(2), 16)
                cseq = int(m.group(3))
                state = int(m.group(4))
                src = int(m.group(5))
                contrib_id = int(m.group(6))
                hopseq = int(m.group(7))
                size = int(m.group(8))
                self.coll.update("ring", cseq, contrib_id, size, ts, nodeid, src)
#                print "COLLECTIVES: Append remote contrib: " + pline["logline"]
                return 1

        return 0
