/*
 * Copyright (c) 2004-2006 The Trustees of Indiana University and Indiana
 *                         University Research and Technology
 *                         Corporation.  All rights reserved.
 * Copyright (c) 2006      Cisco Systems, Inc.  All rights reserved.
 * Copyright (c) 2015-2020 Mellanox Technologies, Inc.
 *                         All rights reserved.
 * Copyright (c) 2016      Intel, Inc.  All rights reserved.
 */

#include <stdio.h>
#include <sys/time.h>
#include <limits.h>
#include <pmix.h>
#include "utils.h"

int main(int argc, char* argv[])
{
    char *dirname, fname[PATH_MAX];
    char hname[HOST_NAME_MAX];
    double start, init, put, commit, fence, fini;
    pmix_value_t value, *val = &value;
    int rank, key_size, rc;
    char *key_val = NULL;
    pmix_info_t *info = NULL;
    pmix_proc_t this_proc, job_proc;
    pmix_proc_t proc;
    bool info_val = 1;
    int ninfo = 0;

    start = get_ts();

    /* Initialize PMIx */
#if (PMIX_VERSION_MAJOR == 1 )
    if (PMIX_SUCCESS != (rc = PMIx_Init(&this_proc)))
#else
    if (PMIX_SUCCESS != (rc = PMIx_Init(&this_proc, NULL, 0)))
#endif
    {
        fprintf(stderr, "Client ns %s rank %d: PMIx_Init failed: %d", this_proc.nspace, this_proc.rank, rc);
        return 0;
    }
    init = get_ts();
    rank = this_proc.rank;

    if( (argc < 3) ){
        if (rank == 0) {
            printf("Require 2 parameters:\n\t(a) key size;\n\t(b) output directory name\n");
        }
        goto err_exit;
    } else {
        key_size = atoi(argv[1]);
        key_val = calloc(key_size, 1);
        dirname = argv[2];
    }

    /* Put the key of the requested size */
    value.type = PMIX_BYTE_OBJECT;
    value.data.bo.size = key_size;
    value.data.bo.bytes = (char*)key_val;
    if (PMIX_SUCCESS != (rc = PMIx_Put(PMIX_REMOTE, "probe", &value))) {
        fprintf(stderr, "Client ns %s rank %d: PMIx_Put internal failed: %d", this_proc.nspace, this_proc.rank, rc);
        goto err_exit;
    }
    put = get_ts();
    
    /* Commit the data */
    if (PMIX_SUCCESS != (rc = PMIx_Commit())) {
        fprintf(stderr, "Client ns %s rank %d: PMIx_Commit failed: %d",
                this_proc.nspace, this_proc.rank, rc);
        goto err_exit;;
    }
    commit = get_ts();

    /* Perform the Fence */
    info_val = 1;
    PMIX_INFO_CREATE(info, 1);
    (void)strncpy(info->key, PMIX_COLLECT_DATA, PMIX_MAX_KEYLEN);
    pmix_value_load(&info->value, &info_val, PMIX_BOOL);
    ninfo = 1;

    /* call fence to ensure the data is received */
    PMIX_PROC_CONSTRUCT(&proc);
    (void)strncpy(proc.nspace, this_proc.nspace, PMIX_MAX_NSLEN);
    proc.rank = PMIX_RANK_WILDCARD;

    if (PMIX_SUCCESS != (rc = PMIx_Fence(&proc, 1, info, ninfo))) {
        fprintf(stderr,  "Client ns %s rank %d: PMIx_Fence failed: %d",
                this_proc.nspace, this_proc.rank, rc);
        goto err_exit;
    }
    PMIX_INFO_FREE(info, ninfo);
    fence = get_ts();

#if (PMIX_VERSION_MAJOR == 1 )
    if (PMIX_SUCCESS != (rc = PMIx_Finalize()))
#else
    if (PMIX_SUCCESS != (rc = PMIx_Finalize(NULL, 0)))
#endif
    {
        fprintf(stderr, "Client ns %s rank %d:PMIx_Finalize failed: %d\n", this_proc.nspace, this_proc.rank, rc);
        return 0;
    }
    fini = get_ts();

    if( argc >=  2) {
        FILE *fp;
        gethostname(hname, HOST_NAME_MAX - 1);
        hname[HOST_NAME_MAX - 1] = '\0';
        sprintf(fname, "%s/pmix_probe_%s_%s.%d", dirname, slurm_jobid(), hname, rank);
        fp = fopen(fname, "w");
        if( NULL == fp ){
        	printf("[%d] ERROR: Cannot open file %s\n", rank, fname);
        } else {
	        fprintf(fp, "process_launch: %lf\n", start);
    	    fprintf(fp, "PMIx init done: %lf\n", init);
        	fprintf(fp, "PMIx put done: %lf\n", put);
	        fprintf(fp, "PMIx Commit done: %lf\n", commit);
    	    fprintf(fp, "PMIx Fence done: %lf\n", fence);
        	fprintf(fp, "PMIx Finalize done: %lf\n", fini);
	        fclose(fp);
	    }
    }
    
    return 0;
err_exit:
#if (PMIX_VERSION_MAJOR == 1 )
    if (PMIX_SUCCESS != (rc = PMIx_Finalize()))
#else
    if (PMIX_SUCCESS != (rc = PMIx_Finalize(NULL, 0)))
#endif
    {
        fprintf(stderr, "Client ns %s rank %d:PMIx_Finalize failed: %d\n", this_proc.nspace, this_proc.rank, rc);
        return 0;
    }
    return 0;
}
