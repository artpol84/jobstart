#!/usr/bin/python

class contribRingStats:
    def __init__(self):
        self.imbalance = 0

class contribRing:
    def __init__(self, seq, contrib_id):
        self.cseq = seq
        self.cid = contrib_id
        self.ts = { }
        self.ts_s = None
        self.graph = { }
        self.size = -1
        self.is_sorted = 0

    def keys(self):
        return sort(self.ts.keys())

    def __getitem__(self, key):
        return self.contribs[key]

    def append(self, size, ts, dst, src = -1):
        self.ts[dst] = ts
        self.graph[dst] = src
        if(self.size > 0):
            assert(self.size == size), "ERROR: Ring seq=" + str(self.cseq) + " contrib=" + str(self.cid) + " size mismatch: " + str(self.size) + " expected, " + str(size) + " found."
        else:
            self.size = size
        self.is_sorted = 0

    def cnt(self):
        return len(self.ts)

    def sort(self):
        if( not self.is_sorted):
            self.ts_s = sorted(self.ts.items(), key = lambda kv : (kv[1], kv[0]))

    def local(self):
        self.sort()
        dst = self.ts_s[0][0]
        assert(self.graph[dst] == -1), "ERROR: Ring seq=" + str(self.cseq) + " contrib=" + str(self.cid) + " local contribution wasnt found"
        return self.ts_s[0]

    def nth_hop(self, idx):
        self.sort()
        assert(idx < self.cnt()), "ERROR: Ring seq=" + str(self.cseq) + " contrib=" + str(self.cid) + " hop #" + idx + " requested, max = " + str(self.cnt())
        t1 = self.ts_s[idx]
        return t1

    def dump(self):
        rev_graph = { }
        start = None
        for i in self.graph.keys():
            if( self.graph[i] >= 0 ):
                rev_graph[self.graph[i]] = i
            else:
                start = i
        l = self.cnt()
        duration = self.nth_hop(l-1)[1] - self.local()[1]
        print "Contribution #", self.cid, "(", duration, ")"
        while (start in rev_graph.keys()):
            lat = int((self.ts[rev_graph[start]] - self.ts[start]) * 1E6)
            print "\tFrom ", start, " to ", rev_graph[start], " time: ", lat, "us"
            start = rev_graph[start]

class collRing:
    def __init__(self, cluster, seqid):
        self.cluster = cluster
        self.seq = seqid
        self.contribs = { }
        self.contribs_s = None

    def update(self, contrib_id, size, ts, dst, src = -1):
        if( not (contrib_id in self.contribs.keys())):
            self.contribs[contrib_id] = contribRing(self.seq, contrib_id)
        self.contribs[contrib_id].append(size, ts, dst, src)

    def summary(self):
        local = { }
        for cid in self.contribs.keys():
            local[cid] = self.contribs[cid].local()
        boot_ts = self.cluster.boot_ts()
#        print local
        local_s = sorted( local.items(), key = lambda kv : (kv[1][1]))

        print "Offset from Boot time: ", local_s[0][1][1] - boot_ts
#        print local_s
        l = len(local_s)
        print "Start imbalance: ", (local_s[l-1][1][1] - local_s[0][1][1]), " fastest nodeid=", local_s[0][1][0], " slowest nodeid=", local_s[l-1][1][0]

        final = { }
        hopcnt = [ self.contribs[val].cnt() for val in self.contribs.keys() ]
        hopcnt.sort()
        assert (hopcnt[0] == hopcnt[len(hopcnt)-1]), "ERROR: Ring seq=" + str(self.cseq) + " contributions have different number of hops, not possible"
        for cid in self.contribs.keys():
            final[cid] = self.contribs[cid].nth_hop(hopcnt[0] - 1)[1] - self.contribs[cid].local()[1]
#        print final
        final_s = sorted( final.items(), key = lambda kv : (kv[1]))
#        print final_s
        print "Contribution propagation imbalance: ", (final_s[l-1][1] - final_s[0][1])
        print final_s

    def dump(self):
        bycid  = sorted( self.contribs.items())
        print bycid
        for cid in bycid:
            cid[1].dump()

class collectives:
    def __init__(self, cluster):
        self.cluster = cluster
        self.coll = { }
        self.coll["ring"] = { }

    def update(self, ctype, cseq, contrib_id, size, ts, dst, src = -1):
        if( ctype == "ring"):
            if( not (cseq in self.coll[ctype].keys())):
                self.coll[ctype][cseq] = collRing(self.cluster, cseq)
                print "New 'ring' collective #", cseq
            self.coll[ctype][cseq].update(contrib_id, size, ts, dst, src)

    def summary(self):
        for i in self.coll["ring"].keys():
            print "Collective #", i
            self.coll["ring"][i].summary()

    def dump(self, ctype, seq):
        self.coll[ctype][seq].dump()
