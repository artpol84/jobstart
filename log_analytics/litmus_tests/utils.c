#include <stdio.h>
#include <sys/time.h>
#include <stdlib.h>

double get_ts()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec + tv.tv_usec * 1E-6);    
}


char *slurm_jobid()
{
    static char jobid[256];
    static int initialized = 0;
    if ( !initialized ){ 
        sprintf(jobid, "%s.%s", getenv("SLURM_JOBID"), getenv("SLURM_STEPID"));
    }
    return jobid;
}
