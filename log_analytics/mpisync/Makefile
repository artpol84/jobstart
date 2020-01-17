# Copyright (c) 2020      Mellanox Technologies, Inc.
#                         All rights reserved. *

HEADERS = hpctimer.h mpigclock.h
SOURCES = hpctimer.c mpigclock.c sync.c

MPICC ?= mpicc

all: mpisync

mpisync: $(HEADERS) $(SOURCES)
	$(MPICC) -o mpisync $(SOURCES)

clean:
	rm -f mpisync



