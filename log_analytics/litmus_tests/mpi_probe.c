/*
 * Copyright (c) 2004-2006 The Trustees of Indiana University and Indiana
 *                         University Research and Technology
 *                         Corporation.  All rights reserved.
 * Copyright (c) 2006      Cisco Systems, Inc.  All rights reserved.
 * Copyright (c) 2020      Mellanox Technologies, Inc.
 *                         All rights reserved. *
 */

#include <stdio.h>
#include <sys/time.h>
#include <limits.h>
#include <mpi.h>
#include "utils.h"


int main(int argc, char* argv[])
{
    int rank, size;
    char *dirname, fname[PATH_MAX];
    char hname[HOST_NAME_MAX];
    double ts1, ts2, ts3;

    ts1 = get_ts();
    MPI_Init(&argc, &argv);
    ts2 = get_ts();

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    if( (argc < 2) && (rank == 0)) {
        printf("Require directory name as input argument\n");
    }

    MPI_Finalize();
    ts3 = get_ts();

    if( argc >=  2) {
        FILE *fp;
        dirname = argv[1];
        gethostname(hname, HOST_NAME_MAX - 1);
        hname[HOST_NAME_MAX - 1] = '\0';
        sprintf(fname, "%s/mpi_probe_%s_%s.%d", dirname, slurm_jobid(), hname, rank);
        fp = fopen(fname, "w");
        if( NULL == fp ){
        	printf("[%d] ERROR: Cannot open file %s\n", rank, fname);
        } else {
	        fprintf(fp, "process_launch: %lf\n", ts1);
    	    fprintf(fp, "MPI init done: %lf\n", ts2);
        	fprintf(fp, "MPI Finalize done: %lf\n", ts3);
	        fclose(fp);
	        
	    }
    }
    return 0;
}
