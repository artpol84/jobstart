#!/usr/bin/python
# Copyright (c) 2020      Mellanox Technologies, Inc.
#                         All rights reserved.

import os

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
            self.new_node(nodeid)
        return self.nodes[nodeid]

    