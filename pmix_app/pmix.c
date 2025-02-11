/*
 * Copyright (c) 2015      Mellanox Technologies, Inc.  All rights reserved.
 * Copyright (c) 2016      Intel, Inc.  All rights reserved.
 * $COPYRIGHT$
 *
 * Additional copyrights may follow
 *
 * $HEADER$
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <getopt.h>
#include <limits.h>
#include <string.h>
#include <pmix.h>

int main()
{
    pmix_proc_t this_proc;
    static int _int_size = 0;
    pmix_value_t value, *val = &value;
    pmix_proc_t job_proc;
    int rank, size;
    int rc;

    /* init us */
    if (PMIX_SUCCESS != (rc = PMIx_Init(&this_proc, NULL, 0)))
    {
        fprintf(stderr, "Client ns %s rank %d: PMIx_Init failed: %d", this_proc.nspace, this_proc.rank, rc);
        abort();
    }

    job_proc = this_proc;
    job_proc.rank = PMIX_RANK_WILDCARD;
    /* get our job size */
    if (PMIX_SUCCESS != (rc = PMIx_Get(&job_proc, PMIX_JOB_SIZE, NULL, 0, &val))) {
        fprintf(stderr, "Client ns %s rank %d: PMIx_Get job size failed: %d", this_proc.nspace, this_proc.rank, rc);
        abort();
    }
    size = val->data.uint32;
    rank = this_proc.rank;
//    PMIX_VALUE_RELEASE(val);

    {
        char name[256];
        gethostname(name, 256);
        printf("%s:%d: rank=%d, size = %d\n", name, getpid(), rank, size);
    }

    // One process exits
    if (rank == 1){
	volatile int delay = 0;
	while(delay) {
		sleep(1);
	}
        exit(1);
    }
    // Other processes are hanging
    while(1) { sleep(1); }


    if (PMIX_SUCCESS != (rc = PMIx_Finalize(NULL, 0)))
    {
        fprintf(stderr, "Client ns %s rank %d:PMIx_Finalize failed: %d\n", this_proc.nspace, this_proc.rank, rc);
        abort();
    }

    return 0;
}
