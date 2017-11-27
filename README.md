# jobstart
Jobstart-related software and information


A. Get Slurm deploy scripts:
1. Go to the root directory of the experiment:
```Shell
cd <rootdir>
```
1. Clone deploy scripts
```Shell
$ git clone git@github.com:artpol84/jobstart.git 
```
2. Go to the deploy directory:
```Shell
cd jobstart/slurm_deploy/
```
3. Setup configuration in `deploy_ctl.conf`


B. Bild and start the installation
1. Allocate resources:
```Shell
$ salloc -N <x> -t <y>
```
2. Download all of the packages:
```Shell
$ ./deploy_cmd.sh source_prepare
```
3. Build and install all of the packages: 
```Shell
./deploy_cmd.sh build_all
```
4. Distribute everything
```Shell
$ ./deploy_cmd.sh distribute_all
```
5. Configure Slurm, please see [`jobstart/slurm_deploy/files/slurm.conf.in`](https://github.com/artpol84/jobstart/blob/master/slurm_deploy/files/slurm.conf.in) for the general configuration and provide the customization file <local.conf> with control machine and partitions description (see [`jobstart/slurm_deploy/files/local.conf`](https://github.com/artpol84/jobstart/blob/master/slurm_deploy/files/local.conf) as an example)
```Shell
./deploy_cmd.sh slurm_config ./files/local.conf
```
6. Start the Slurm instance:
```Shell
./deploy_cmd.sh slurm_start
```

C. Check the installation

NOTE: From the other terminal!

1. Check that deploy is functional.
```Shell
$ export SLURMDEP_INST=<INSTALL_DIR from deploy_ctl.conf>
$ cd $SLURMDEP_INST/slurm/bin
$ ./sinfo
<check that the output is correct>
```
3. Allocate nodes inside the deployed Slurm installation:
```Shell
$ ./salloc -N <X> <other options>
```
4. Run hostname to test:
```Shell
$ ./srun hostname
```
5.Run hostname with pmix plugin:
```Shell
./srun --mpi=pmix hostname
```

D. Check with the distributed application

NOTE: from the allocation of deployed Slurm (same terminal as C.)

1. Go to the test app directory
```Shell
$ cd <rootdir>/jobstart/shmem/
```
2. compile the program
```Shell
$ $SLURMDEP_INST/ompi/bin/oshcc -o hello_oshmem_c -g hello_oshmem_c.c # INSTALL_DIR from deploy_ctl.conf
```

3. Launch the application
```Shell
$ cd <rootdir>/jobstart/launch/
$ ./run.sh {dtcp|ducx|sapi} [early|noearly] [openib] [timing] -N <nnodes> -n <nprocs> <other-slurm-opts> ./hello_oshmem_c
```
