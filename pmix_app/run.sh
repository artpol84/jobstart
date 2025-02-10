#!/bin/bash


/tmp/slurm_deploy/slurm/bin/srun -N 3 -p rock --mpi=pmix_v3 ./pmix_app
