# Copyright (c) 2020      Mellanox Technologies, Inc.
#                         All rights reserved. 

MPICC ?= mpicc
CC ?= gcc
CFLAGS = -g -O0

all: mpi_probe pmix_probe

mpi_probe: mpi_probe.c utils.c utils.h
	$(MPICC) $(CFLAGS) -o mpi_probe mpi_probe.c utils.c

pmix_probe: pmix_probe.c utils.c utils.h
	$(CC) $(CFLAGS) -o pmix_probe pmix_probe.c utils.c -I$(PMIX_BASE)/include -L$(PMIX_BASE)/lib -lpmix -Wl,-rpath=$(PMIX_BASE)/lib

clean:
	rm -f mpi_probe pmix_probe



