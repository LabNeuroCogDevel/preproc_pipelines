#!/usr/bin/env bash
## USAGE
# $0 datasource pipeline [ids]
# 
#  run preprocessing pipeline on datasource data
#   - datasource is a file in data/
#   - pipeline is a file in pipelines
#   - OPTIONAL: subject ids to spefically run on
#  SPECIAL VAIRABLES
#   - ONEONLY   -- only run one subject
#   - TESTONLY  -- print which subjects would be run
#   - MAXJOBS   -- change default max no jobs
#  
## END USAGE

[ -n "$VERBOSE" ] && set -x

#####
# get list of datasource and pipeline options
# printted during usage message
function listdir {
  srcdir=$SCRIPTDIR/$1
  [ ! -d $srcdir ] && err "no directory '$srcdir'"

  find $srcdir -type f -not -name template -not -name '.*' -and -not -name '*.swp'| while read f; do
    date="$(sed -n 's/"//g;s/.*_VERSION=//p' "$f")"
    desc="$(sed -n 's/"//g;s/.*DESC80=//p' "$f")"
    echo -e "$(basename $f)\t$date\t$desc"
  done | column -ts'	'|sed 's/^/    /' |sort -k2,2nr
}
function list_pipeandsource {
  echo "
 #datasources#
$(listdir sources)
 #pipelines#
$(listdir pipes)
"
}
####

# default to 8 max jobs
[ -z "$MAXJOBS" ] && MAXJOBS=8
# SLEEPTIME default is 60

scriptdir=$(cd $(dirname $0);pwd)
source $scriptdir/funs_src.bash

[ "$1" = "-h" ] && help && list_pipeandsource && exit 0
[ -z "$1" ] && usage "need better arguemnts, try $(list_pipeandsource)"

datasource="$1"; pipeline="$2";

# we can specify datasource and pipeline as files
# but if we didn't, check inisde a subdirectory
[ ! -r $datasource    ] && datasource="$scriptdir/sources/$1"
# before we go on, make sure we have a datasource and pipeline file
[ ! -r "$datasource"    ] && usage "cannot read datasource ($1) file '$datasource'"
source $datasource || err "could not source $datasource'"

# list all subjects if not given a pipeline, still exit with error
if [ -z "$pipeline" ]; then 
   list_all
   exit 0
fi

[ ! -r "$pipeline" ] && pipeline="$scriptdir/pipes/$2"
[ ! -r "$pipeline" ] && usage "cannot read pipeline ($2) file '$pipeline'" 
# get the goodies inside each file
source $pipeline   || err "could not source $pipeline"

## we want to take the arguements as ids
## or use the list_all function from datasource
shift; shift;


# set the exit trap so we when we die 
trap trapmsg EXIT

# JOB CONTROL
# replace waitforjobs with a more robust version
waitforjobssrc="/opt/ni_tools/lncdshell/utils/waitforjobs.sh"
export JOBCFGDIR="$scriptdir/.jobcfg/$(basename $pipeline)-$(hostname)"
WAITTIME=300
if test -r $waitforjobssrc; then
   source $waitforjobssrc
else 
   echo "could not find '$waitforjobssrc'; bash source needed for waitforjobs"
   exit 1
fi
echo "# set jobs in $JOBCFGDIR"

# def function to pick which to use
# arguments as ids on the commad line
# or list_all sourced from datasource file
function args_or_list_all_ids {
  if [ -z "$1" ]; then
   list_all
  elif [[ "$1" == "all" && $# -eq 1 ]]; then
   local s="$(basename $datasource)"; local p="$(basename $pipeline)";
   pp_status $s $p diff| perl -slane 'next unless $.>3; print $F[1]'
  else
   for id in $@; do echo $id; done
  fi
}



#  - check for final out
#  - run dependencies
#  - run run_pipeline
function runwithdepends {
 id=$1

 ## Do we need to run? Have we already finished
 # default to already finished until we are missing a final output
 check_complete $id && return 0


 ## run dependancies
 # make sure all dependencies are run
 local alldepends="yes"
 for depend in ${PIPE_DEPENDS[@]}; do
   if ! $scriptdir/$(basename $0) $(basename $datasource) $(basename $depend) $id; then
     warn "SKIPPING: cannot finish $id's depend $depend"
     alldepends="no"
     break
   fi
 done
 [ "$alldepends" == "no" ] && return 1


 # if we are testing, just print the ID we would have run
 if [ -n "$TESTONLY" ]; then
   echo "# run_pipeline $id # [$datasource $pipeline]"
 else
   # ! run_pipeline $id && err "did not succesfully finish run_pipeline $id"
   local lockfile=$SCRIPTDIR/locks/$(basename $datasource)_$(basename $pipeline)_$id
   check_write_lock $lockfile

   ### THIS IS IT: RUN THE PIPELINE
   # on error, remove the lock
   if ! run_pipeline $id; then 
     warn "did not succesfully finish run_pipeline $id" 
     rm $lockfile
     return 1
   fi

   rm $lockfile
 fi
 
 # group can write for all pipelines
 [ -d "$PPSUBJSDIR/$id" ] && chmod -R g+w "$PPSUBJSDIR/$id"

 wait

 return 0
}

## ACTUALLY DO STUFF

# get to the subjects root directory for this datasource/pipeline
PPSUBJSDIR="/Volumes/Zeus/preproc/$(basename $datasource)/$(basename $pipeline)"
[ ! -d "$PPSUBJSDIR" ] && mkdir -p $PPSUBJSDIR

PIDS=()

# warp it all together
args_or_list_all_ids $@ | while read id; do

 cd $PPSUBJSDIR
 # only one ID, don't fork
 # but end in error if we dont finish succesfully 
 if [ $# -eq 1 -o -n "$ONEONLY" ]; then
   runwithdepends $id  || err "could not finish $id"
   break
 fi

 echo -e "\n### RUNNING $id ###"

 # only one job, dont fork
 # but only warn if we dont finish
 if [ $MAXJOBS -eq 1 ]; then
   echo "# running $datasource::$pipeline for $id ($(njobs)/$MAXJOBS jobs)"
   runwithdepends $id  || warn "could not finish $id"
   echo "# finished $id"
   continue

 #fork: run a whole bunch at the same time
 else
   runwithdepends $id &
   PIDS=(${PIDS[@]} $!)
   echo "# launched $datasource::$pipeline for $id ($(njobs)/$MAXJOBS jobs)"
   # wait a second for jobs to report they've already finished
   sleep 0.5
   waitforjobs "last was $id"
 fi
done

#echo "# all jobs forked, waiting to complete"
echo "# Done launching jobs. waiting for all to fininish ($(njobs) jobs w/PIDS $PIDS)"
#pstree -sp $$
# any jobs forked by children are not catpured here
#[ $# -gt 1 -o $MAXJOBS -gt 1 ] && ps
wait
