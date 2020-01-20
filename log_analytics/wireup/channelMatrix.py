#!/usr/bin/python

import statistics as stat

class message:
    def __init__(self, type):
        self._size = 0
        self._mid = -1
        self.ts = { }

    def set_size(self, size):
        self._size = size
    def size(self):
        return self._size

    def set_mid(self, mid):
        self._mid = mid
    def mid(self):
        return self._mid

    def in_state(self, state):
        return (state in self.ts.keys())

    def dump_states(self):
        states = ""
        for state in self.ts.keys():
            states += state + ", "
        return states

    def set_ts(self, state, ts):
        assert (not self.in_state(state)), "ERROR: Double message state initialization"
        self.ts[state] = ts

    def ts(self, state):
        return self.ts[state]

class channel:
    SEND = 1
    RECV = 2

    def __init__(self):
        self.ch = { }
        self.ch[self.SEND] = { }
        self.ch[self.RECV] = { }
        self.fifo = { }
        self.fifo[self.SEND] = []
        self.fifo[self.RECV] = []


    def update(self, side_str, mid, mtype, size, ts):
        if( not (mid in self.ch[side].keys())):
            msg = message()
            msg.set_size(size)
            msg.set_mid(mid)
            self.ch[side][mid] = msg
            self.fifo[side].append(msg)
        msg = self.ch[side][mid]
        assert (self.ch[side][mid].size() == size), "Message size mismatch"
        msg.set_ts(mtype, ts)

    def match(self):
        l = min(len(self.fifo[self.]), len(self.fifo["recv"]))
        for i in xrange(0, l):
            # Debug output
            # print "Match message #", i
            smsg = self.fifo[self.SEND][i]
            rmsg = self.fifo[self.RECV][i]
            if (smsg.size() != rmsg.size()):
                ret = "Matching ERROR: message #" + str(i) + ": size: send=" + str(smsg.size()) + " recv=" + str(rmsg.size())
                return ret
            if (not smsg.in_state("completed")):
                ret = "Matching ERROR: message #" + str(i) + ": send is not completed: " + smsg.dump_states()
                return ret
            if (not rmsg.in_state("completed")):
                ret = "Matching ERROR: message #" + str(i) + ": recv is not completed: " + rmsg.dump_states()
                return ret
        if ( len(self.fifo[self.SEND]) != len(self.fifo[self.RECV]) ):
            ret = "Matching ERROR: mismatch in # of send and recv messages: send=" + str( len(self.fifo[self.SEND]) ) + " recv=" + str( len(self.fifo[self.RECV]) )
            return ret
        return None

    def comm_time(self, start_state, end_state):
        l = len(self.fifo[self.SEND])
        time = 0.0
        for i in xrange(0, l):
            smsg = self.fifo[self.SEND][i]
            rmsg = self.fifo[self.RECV][i]
            time += rmsg.ts(end.state) - smsg.ts(start.state)
        return time

    def latencies(self, start_state, end_state):
        l = len(self.fifo[self.SEND])
        lat = [ ]
        for i in xrange(0, l):
            smsg = self.fifo[self.SEND][i]
            rmsg = self.fifo[self.RECV][i]
            lat.append({ "size" : rmsg.size(), "lat" : (rmsg.ts(end.state) - smsg.ts(start.state))])
        return lat


class channelMatrix:
    def __init__(self, send_side_name, recv_side_name):
        self.matrix = { }
        self.sides = {}
        self.sides[send_side_name] = channel.SEND
        self.sides[recv_side_name] = channel.RECV

    def update(self, src, dst, side_str, mtype, mid, size, ts):
        assert (side_str in self.side)), "[channel]: Unknown side name \"", side_str, "\""
        side = self.sides[side_str]
        if( not (src in self.matrix.keys())):
            self.matrix[src] = { }
        if( not (dst in self.matrix[src].keys())):
            self.matrix[src][dst] = channel()
        self.matrix[src][dst].update(side, mid, mtype, size, ts)

    def match(self):
        for src in self.matrix.keys():
            for dst in self.matrix[src].keys():
                err = self.matrix[src][dst].match()
                if( err != None):
                    src_node = 
                    print "(", str(src) + ",", str(dst), "): ", err

    def comm_time(self, sender_state, receiver_state):
        output = [None] * len(self.matrix.keys())
        for src in self.matrix.keys():
            output[src] = [None] * len(self.matrix[src].keys())
            for dst in self.matrix[src].keys():
                ctime = self.matrix[src][dst].comm_time(sender_state, receiver_state)
                output[src][dst] = ctime
        return output

    def comm_lat(self, sender_state, receiver_state):
        output = { }
        for src in self.matrix.keys():
            output[src] = [None] * len(self.matrix[src].keys())
            for dst in self.matrix[src].keys():
                latencies = self.matrix[src][dst].latencies(sender_state, receiver_state)
                for l in latencies:
                    size = l["size"]
                    if( not (size in output.keys())):
                        output["data"][size] = [ ]
                    x = {"src" : src, "dst" : dst, "lat" : l["lat"] }
                    output["data"][size].append(x)

        output["stat"] = { }
        output["stat"]["size"] = [None] * len(output.keys())
        output["stat"]["mean"] = [None] * len(output.keys())
        output["stat"]["stdev"] = [None] * len(output.keys())
        idx = 0
        for size in output.keys():
            values = []
            for l in output[size]["data"]:
                values.append(l["lat"])
            output["stat"][idx]["size"] = size
            output["stat"][idx]["mean"] = stat.mean(values)
            output["stat"][idx]["stdev"] = stat.stdev(values, output["stat"][idx]["mean"])
            idx += 1

        return output

    def verification(self):
        # Verify message send/recv matching
        self.match()
#        self.heatmap()
        self.comm_time()