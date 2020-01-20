#!/usr/bin/python
# Copyright (c) 2020      Mellanox Technologies, Inc.
#                         All rights reserved.

import os

#                                                                    #
# ========================== Global time =========================== #
#                                                                    #

class globalTime:
    def __init__(self, cluster):
        self.initialized = False
        self.cluster = cluster
        self.by_host = { }
        self.by_id = { }

    def load(self, fname):
        # Read file
        with open(fname, 'r') as f:
            text = f.readlines()
        f.close()
        for l in text:
            fields = l.split(" ")
            if( len(fields) < 1):
                print "Global Time sync file (mpisync) is corrupted"
                os.abort()
            if( fields[0] == "#"):
                continue
            if( len(fields) != 3 ):
                print "Global Time sync file (mpisync) is corrupted"
                os.abort()
            self.by_host[fields[0]] = float(fields[2])
        self.initialized = True

    def set_cluster(cluster):
        cnt = 0
        for i in self.cluster.nodes:
            if (not (i.hostname() in self.by_host.keys()):
                print "Host ", i.hostname(), " is not found in the Time sync file (mpisync)"
                os.abort()
            cnt++;

    def global_ts(self, nodeid, local_ts):
        if( self.initialized ):
            return local_ts
        if( not nodeid in self.by_id.keys()):
            node = self.cluster.node(nodeid)
            error = "global_ts: Unknown nodeid=" + str(nodeid)
            assert ( node != None ), error
            self.by_id[nodeid] = self.by_host[node.hostname()]
        return local_ts + self.by_id[nodeid]
#                                                                    #
# ========================== Node state ============================ #
#                                                                    #

class clusterNode:
    def __init__(self, nodeid):
        self.nodeid = nodeid
        self.host_name = None
        self.progress = { }

    def set_hostname(self, hostname):
        self.host_name = hostname

    def hostname(self):
        return self.host_name

class clusterSystem:
    def __init__(self):
        self.nodes = { }

    def new_node(self, nodeid):
        self.nodes[nodeid] = clusterNode(nodeid)
        return self.nodes[nodeid]

    def node(self, nodeid):
        if( not (nodeid in self.nodes.keys())):
            return None
        return self.nodes[nodeid]

    