#!/bin/bash
# source script to load GPC-specific settings for pyWPS, WPS, and WRF
# created 06/07/2012 by Andre R. Erler, GPL v3
# revised 09/05/2014 by Andre R. Erler, GPL v3

# some code to make seamless machine transitions work on SciNet
if [[ -n "$QSYS" ]] && [[ -n "$WRFSCRIPT" ]] && [[ "$QSYS" != 'PBS' ]]; then
  # since the run-script defined before, is not for LL, we need to change the extension
  export WRFSCRIPT="${WRFSCRIPT%.*}.pbs"
fi # if previously not PBS
# this machine
export MAC='GPC' # machine name
export QSYS='PBS' # queue system

if [ -z $SYSTEM ] || [[ "$SYSTEM" == "$MAC" ]]; then 
# N.B.: this script may be sourced from other systems, to set certain variables...
#       basically, everything that would cause errors on another machine, goes here

  # load modules
	echo
	module purge
	#module load intel/15.0.2 intelmpi/4.1.0.027 hdf5/1814-v18-serial-intel netcdf/4.3.3.1_serial-intel cdo/1.6.9-intel extras/64_6.4
  module load intel/13.1.1 intelmpi/4.1.0.027 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel extras/64_6.4
  #module load intel/12.1.5 openmpi/1.4.4-intel-v12.1 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel extras/64_6.4
  #module load intel/12.1.3 intelmpi/4.0.3.008 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel
	module load gcc/4.8.1 anaconda2/4.1.1 ncl/6.2.0 extras/64_6.4 # need Python 2.7
	# N.B.: extras/64 is necessary for Grib2 support (libjasper and libpng12)
  # pyWPS.py specific modules
	#if [[ ${RUNPYWPS} == 1 ]]; then
	#    module load gcc/4.8.1 python/2.7.3 ncl/6.1.0 extras/64_6.4
	#    # N.B.: extras/64 is necessary for Grib2 support (libjasper and libpng12)
	#    #module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
	#fi
	module list
	echo

  # unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
  ulimit -s unlimited
  
  # set the functions that are used in CMIP5 cases
  function ncks() { modulewrap -hdf5/187-v18-serial-intel,-netcdf/4.1.3_hdf5_serial-intel,hdf5/1814-v18-serial-intel,netcdf/4.3.3.1_serial-intel,udunits/2.1.11,gsl/1.15-intel,nco/4.4.8-intel command ncks $@; }
  export -f ncks
  
  function cdo() { modulewrap -hdf5/187-v18-serial-intel,-netcdf/4.1.3_hdf5_serial-intel,hdf5/1814-v18-serial-intel,netcdf/4.3.3.1_serial-intel,cdo/1.6.9-intel command cdo $@; }
  export -f cdo
  
  function cdb_query_6hr() { modulewrap -hdf5/187-v18-serial-intel,-netcdf/4.1.3_hdf5_serial-intel,hdf5/1814-v18-serial-intel,netcdf/4.3.3.1_serial-intel command cdb_query $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} "''" ${20} ${21};}
  export -f cdb_query_6hr
  
  function cdb_query_day() { modulewrap -hdf5/187-v18-serial-intel,-netcdf/4.1.3_hdf5_serial-intel,hdf5/1814-v18-serial-intel,netcdf/4.3.3.1_serial-intel command cdb_query $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} "''" ${14} ${15};}
  export -f cdb_query_day
  
  function cdb_query_month() { modulewrap -hdf5/187-v18-serial-intel,-netcdf/4.1.3_hdf5_serial-intel,hdf5/1814-v18-serial-intel,netcdf/4.3.3.1_serial-intel command cdb_query $1 $2 $3 $4 $5 $6 $7 $8 $9 "''" ${11} ${12};}
  export -f cdb_query_month
  
  
fi # if on GPC

# RAM-disk settings: infer from queue
if [[ ${RUNPYWPS} == 1 ]] && [[ ${RUNREAL} == 1 ]]
  then
    #if [[ "${PBS_QUEUE}" == 'largemem' ]]; then
    if [ $(( $(free | grep 'Mem:' | awk '{print $2}') / 1024**2 )) -gt 100 ]; then
	export RAMIN=${RAMIN:-1}
	export RAMOUT=${RAMOUT:-1}
    else
	export RAMIN=${RAMIN:-1}
	export RAMOUT=${RAMOUT:-0}
    fi # PBS_QUEUE
  else
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
fi # if WPS
echo
echo "Running on ${PBS_QUEUE} queue; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
echo

# RAM disk folder (cleared and recreated if needed)
export RAMDISK="/dev/shm/${USER}/"
# check if the RAM=disk is actually there
if [[ ${RAMIN}==1 ]] || [[ ${RAMOUT}==1 ]]; then
    # create RAM-disk directory
    mkdir -p "${RAMDISK}"
    # report problems
    if [[ $? != 0 ]]; then
      echo
      echo "   >>>   WARNING: RAM-disk at RAMDISK=${RAMDISK} - folder does not exist!   <<<"
      echo
    fi # no RAMDISK
fi # RAMIN/OUT
	
# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# set up hybrid envionment: OpenMP and MPI (Intel)
export NODES=${NODES:-${PBS_NUM_NODES}} # set in PBS section
export TASKS=${TASKS:-16} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
#export KMP_AFFINITY=verbose,granularity=thread,compact
#export I_MPI_PIN_DOMAIN=omp
export I_MPI_DEBUG=1 # less output (currently no problems)
# Intel hybrid (mpi/openmp) job launch command
export HYBRIDRUN=${HYBRIDRUN:-'mpirun -ppn ${TASKS} -np $((NODES*TASKS))'} # evaluated by execWRF and execWPS

# geogrid command (executed during machine-independent setup)
export RUNGEO=${RUNGEO:-"ssh gpc-f104n084-ib0 \"cd ${INIDIR}; source ${SCRIPTDIR}/setup_WPS.sh; mpirun -n 4 ${BINDIR}/geogrid.exe\""} # run on GPC via ssh
#export RUNGEO=${RUNGEO:-"mpirun -n 4 ${BINDIR}/geogrid.exe"}

# WPS/preprocessing submission command (for next step)
# export SUBMITWPS=${SUBMITWPS:-'ssh gpc01 "cd \"${INIDIR}\"; qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}"'} # evaluated by launchPreP
#export SUBMITWPS=${SUBMITWPS:-'bash -c "cd \"${INIDIR}\"; export WRFWCT=${WRFWCT}; export WPSWCT=${WPSWCT}; export NEXTSTEP=${NEXTSTEP}; export WPSSCRIPT=${WPSSCRIPT}; python ${SCRIPTDIR}/selectWPSqueue.py"'} # use Python script to estimate queue time and choose queue
# N.B.: the 'bash -c' command is necessary in order to remain consistent with the ssh commands used from other machines
export SUBMITWPS=${SUBMITWPS:-"$( cat <<-_______END_OF_COMMAND
      ssh gpc-f104n084-ib0 "cd '\${INIDIR}' 
														export WRFWCT='\${WRFWCT}'; export WPSWCT='\${WPSWCT}'; export NEXTSTEP='\${NEXTSTEP}'
														export QNDS=4; export QPPN='16,20'; export QSHOW='showq -w class=largemem'
														export QONE='qsub \${WPSSCRIPT} -v NEXTSTEP={0:s} -l nodes=1 -q largemem '
														export QTWO='qsub \${WPSSCRIPT} -v NEXTSTEP={0:s} -l nodes=1:m32g:ppn=8 -q batch'
														python '\${SCRIPTDIR}/selectWPSqueue.py'"
_______END_OF_COMMAND
                                 )"} # use Python script to estimate queue time and choose queue
# N.B.: this is a "here document"; variable substitution should happen at the eval stage
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step in the interval)
#export SUBMITAR=${SUBMITAR:-'ssh gpc-f104n084-ib0 "cd \"${INIDIR}\"; echo \"${ARTAG}\" >> HPSS_backlog.txt"; echo "Logging archive tag \"${ARTAG}\" in 'HPSS_backlog.txt' for later archiving."'} # evaluated by launchPostP
## N.B.: instead of archiving, just log the year to be archived; this is temporarily necessary,  because HPSS is full
export SUBMITAR=${SUBMITAR:-'ssh gpc-f104n084-ib0 "cd \"${INIDIR}\"; qsub ./${ARSCRIPT} -v TAGS=${ARTAG},MODE=BACKUP,INTERVAL=${ARINTERVAL}"'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# averaging submission command (for last step in the interval)
export SUBMITAVG=${SUBMITAVG:-'ssh gpc-f104n084-ib0 "cd \"${INIDIR}\"; qsub ./${AVGSCRIPT} -p 500 -v PERIOD=${AVGTAG}"'} # evaluated by launchPostP
# N.B.: requires $AVGTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'ssh gpc-f104n084-ib0 "cd \"${INIDIR}\"; qsub ./${WRFSCRIPT} -v NOWPS=${NOWPS},NEXTSTEP=${NEXTSTEP},RSTCNT=${RSTCNT}"'} # evaluated by resubJob

# sleeper job submission (for next step when WPS is delayed)
export SLEEPERJOB=${SLEEPERJOB-'ssh p7n01-ib0 "cd \"${INIDIR}\"; nohup ./${STARTSCRIPT} --restart=${NEXTSTEP} --name=${JOBNAME} &> ${STARTSCRIPT%.sh}_${JOBNAME}_${NEXTSTEP}.log &"'} # evaluated by resubJob; relaunches WPS
# N.B.: all sleeper jobs should be submitted to P7
