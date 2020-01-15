
string="[2020-01-15T04:07:51.707] [6.8] debug:  [(null):0] [1579054071.707138] [mpi_pmix.c:153:p_mpi_hook_slurmstepd_prefork] mpi/pmix:  start"
print("filter:", flt.apply(string))

string="[2020-01-15T04:07:51.933] [6.8] debug:  [clx-hercules-004:0] [1579054071.933820] [pmixp_agent.c:227:_agent_thread] mpi/pmix:  Start agent thread"
print("filter:", flt.apply(string))

string="[2020-01-15T04:07:51.934] [6.8] debug:  [clx-hercules-004:0] [1579054071.934096] [pmixp_server.c:1323:_wireup_thread] mpi/pmix:  WIREUP/early: sending initiation message to nodeids: 1 "
print("filter:", flt.apply(string))

string="[2020-01-15T04:07:51.935] [6.8] debug:  [clx-hercules-004:0] [1579054071.935396] [pmixp_server.c:1330:_wireup_thread] mpi/pmix:  WIREUP/early: complete"
print("filter:", flt.apply(string))

string="[2020-01-15T04:07:52.011] [6.8] debug:  [clx-hercules-005:1] [1579054072.011693] [pmixp_dconn.h:228:pmixp_dconn_connect] mpi/pmix:  WIREUP: Connect to 2"
print("filter:", flt.apply(string))


string = "[2020-01-16T04:16:41.356] [6.8] debug:  [clx-hercules-058:0] [1579141001.356135] [pmixp_dconn_ucx.c:763:_ucx_send] mpi/pmix:  UCX: send [enqueued] nodeid=1, mid=0, size=702"
print("filter:", flt.apply(string))

string = "[2020-01-16T04:16:41.376] [6.8] debug:  [clx-hercules-058:0] [1579141001.376715] [pmixp_dconn_ucx.c:117:send_handle] mpi/pmix:  UCX: send [completed] nodeid=1, mid=0, size=702"
print("filter:", flt.apply(string))

string = "[2020-01-16T04:16:41.563] [6.8] debug:  [clx-hercules-058:1] [1579141001.563035] [pmixp_dconn_ucx.c:446:_ucx_progress] mpi/pmix:  UCX: recv [enqueued] nodeid=0, mid=0, size=702"
print("filter:", flt.apply(string))

string = "[2020-01-16T04:16:41.563] [6.8] debug:  [clx-hercules-058:1] [1579141001.563079] [pmixp_dconn_ucx.c:498:_ucx_progress] mpi/pmix:  UCX: recv [completed] nodeid=0, mid=0, size=702"
print("filter:", flt.apply(string))

string = "[2020-01-16T04:16:41.356] [6.8] debug:  [clx-hercules-058:0] [1579141001.356135] [pmixp_dconn_ucx.c:763:_ucx_send] mpi/pmix:  UCX: send [enqueued] nodeid=1, mid=1, size=702"
print("filter:", flt.apply(string))

string = "[2020-01-16T04:16:41.376] [6.8] debug:  [clx-hercules-058:0] [1579141001.376715] [pmixp_dconn_ucx.c:117:send_handle] mpi/pmix:  UCX: send [completed] nodeid=1, mid=1, size=702"
print("filter:", flt.apply(string))

string = "[2020-01-16T04:16:41.563] [6.8] debug:  [clx-hercules-058:1] [1579141001.563035] [pmixp_dconn_ucx.c:446:_ucx_progress] mpi/pmix:  UCX: recv [enqueued] nodeid=0, mid=1, size=702"
print("filter:", flt.apply(string))

string = "[2020-01-16T04:16:41.563] [6.8] debug:  [clx-hercules-058:1] [1579141001.563079] [pmixp_dconn_ucx.c:498:_ucx_progress] mpi/pmix:  UCX: recv [completed] nodeid=0, mid=1, size=702"
print("filter:", flt.apply(string))
