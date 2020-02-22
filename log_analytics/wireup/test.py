#!/usr/bin/python

import sys
import os
import argparse
import json
import inspect
import re

# Cluster resources
#import clusterResources as cr

#c = cr.clusterSystem()
#c.new_node(0)
#c.node(0).set_hostname("cn0")
#c.new_node(1)
#c.node(1).set_hostname("cn1")

#gt = cr.globalTime(c)
#gt.load("sync")

#ts = 5
#print "Ts=", ts, " cn0 = ", gt.global_ts(0, ts), " cn1 = ", gt.global_ts(1, ts)


#import numpy as np; 
#np.random.seed(0)
#import seaborn as sns; sns.set()
#uniform_data = np.random.rand(10, 12)
#ax = sns.heatmap(uniform_data)

s="mpi_probe_2.25_clx-hercules-002.0"
regex="mpi_probe_(\S+)_\S+"
r = re.compile(regex)
m = r.match(s)
print "match = ", m
print "match = ", m.group(1)

s="pmix_probe_2.27_clx-hercules-002.0"
regex="pmix_probe_(\S+)_\S+"
r = re.compile(regex)
m = r.match(s)
print "match = ", m
print "match = ", m.group(1)


sys.exit()

s = ' 0x956ce0: ctx=0x956dc8 contrib/nbr: collseq=3, state=1, nodeid=2, contrib=7, hopseq=3, size=19'
regex = "\s(0x[0-9a-fA-F]+):\sctx=(0x[0-9a-fA-F]+)\scontrib/nbr:\scollseq=(\d+),\sstate=(\S+),\snodeid=(\d+),\scontrib=(\d+),\shopseq=(\d+),\ssize=(\d+)"
r = re.compile(regex)
m = r.match(s)
print "match = ", m


sys.exit()

d = {"Pierre": 42, "Anne": 33, "Zoe": 24}

sorted_d = sorted(d.items(), key = lambda kv : (kv[1], kv[0]))
print sorted_d
print sorted_d[0][0]

x = (sorted_d[0][0], sorted_d[0][1])
print x


x = [ (2,4), (1,4), (1, 5) ]
print sorted(x)

