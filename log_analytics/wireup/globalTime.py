#!/usr/bin/python

class globalTime:
    def __init__(self):
        self.initialized = False
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

    def global_ts(self, nodeid, hostname, local_ts):
        if( not self.initialized ):
            return local_ts
        if( not nodeid in self.by_id.keys()):
            error = "global_ts: Unknown nodeid=" + str(nodeid)
            assert ( nodeid != None ), error
#            print "host = ", hostname, ", val = ", self.by_host[hostname]
            self.by_id[nodeid] = self.by_host[hostname]
#        print("nodeid=%d, hostname=%s, offset=%.6f, local_ts=%.6f, ts=%.6f\n" % 
#                (nodeid, hostname, self.by_id[nodeid], local_ts, local_ts + self.by_id[nodeid]))
        return local_ts + self.by_id[nodeid]
