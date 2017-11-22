/*
 * Copyright (c) 2014-2016   Mellanox Technologies, Inc.
 *                           All rights reserved.
 * Copyright (c) 2015        Cisco Systems, Inc.  All rights reserved.
 * $COPYRIGHT$
 *
 * Additional copyrights may follow
 *
 * $HEADER$
 */

#include <stdio.h>
#include "shmem.h"

#if !defined(OSHMEM_SPEC_VERSION) || OSHMEM_SPEC_VERSION < 10200
#error This application uses API 1.2 and up
#endif

#include <time.h>
#define GET_TS ({ \
    struct timespec ts;                     \
    double ret;                             \
    clock_gettime(CLOCK_MONOTONIC, &ts);    \
    ret = ts.tv_sec + 1E-9 * ts.tv_nsec;    \
    ret;                                    \
})

long pSyncRed[_SHMEM_REDUCE_SYNC_SIZE];
double pWrk[_SHMEM_REDUCE_MIN_WRKDATA_SIZE];

int main(int argc, char* argv[])
{
    int proc, nproc;
    char name[SHMEM_MAX_NAME_LEN];
    int major, minor, t;
    static double time, min_time, max_time, avg_time;

    time = GET_TS;
    shmem_init();
    time = GET_TS - time;
    
    nproc = shmem_n_pes();
    proc = shmem_my_pe();
    shmem_info_get_name(name);
    shmem_info_get_version(&major, &minor);


    for ( t = 0; t < _SHMEM_REDUCE_SYNC_SIZE; t += 1) 
        pSyncRed[t] = _SHMEM_SYNC_VALUE;

    shmem_double_min_to_all(&min_time, &time, 1, 0, 0, nproc, pWrk, pSyncRed);
    shmem_double_max_to_all(&max_time, &time, 1, 0, 0, nproc, pWrk, pSyncRed);
    shmem_double_sum_to_all(&avg_time, &time, 1, 0, 0, nproc, pWrk, pSyncRed);
    avg_time = avg_time/nproc;

    if( 0 == proc ){
        printf("procs: %d min: %lf max: %lf avg: %lf\n",
                nproc, min_time, max_time, avg_time);
    }
    shmem_finalize();

    return 0;
}
