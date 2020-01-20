#!/usr/bin/python

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


import numpy as np; 
np.random.seed(0)
import seaborn as sns; sns.set()
uniform_data = np.random.rand(10, 12)
ax = sns.heatmap(uniform_data)