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

# default to 8 max jobs
[ -z "$MAXJOBS" ] && MAXJOBS=8
# SLEEPTIME default is 60

scriptdir=$(cd $(dirname $0);pwd)
source $scriptdir/funs_src.bash

[ -z "$2" ] && usage "need two arguments!"
datasource=$1; pipeline=$2

# we can specify datasource and pipeline as files
# but if we didn't, check inisde a subdirectory
[ ! -r $datasource    ] && datasource="$scriptdir/sources/$1"
[ ! -r $pipeline ] && pipeline="$scriptdir/pipes/$2"

# before we go on, make sure we have a datasource and pipeline file
[ ! -r "$datasource"    ] && usage "cannot read datasource ($1) file '$datasource'"
[ ! -r "$pipeline" ] && usage "cannot read pipeline ($2) file '$pipeline'"

# get the goodies inside each file
source $datasource
source $pipeline

## we want to take the arguements as ids
## or use the list_all function from datasource

# get datasource and pipeline off the arg list
shift; shift;

# set the exit trap so we when we die 
trap trapmsg EXIT

# def function to pick which to use
# arguments as ids on the commad line
# or list_all sourced from datasource file
function args_or_list_all_ids {
  if [ -z "$1" ]; then
   list_all
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
 local alreadyfinished="yes"
 for fout in ${FINALOUT[@]}; do
   [ ! -r $id/$fout ] && alreadyfinished="no" && break
 done
 [ "$alreadyfinished" == "yes" ] && warn "# $(basename $datasource) $(basename $pipeline) $id already finished!" && continue


 ## run dependancies
 # make sure all dependencies are run
 local alldepends="yes"
 for depend in ${PIPE_DEPENDS[@]}; do
   if ! eval $scriptdir/$(basename $0) $(basename $datasource) $(basename $depend) $id ; then
     warn "SKIPPING: cannot finish $id's depend $depend"
     alldepends="no"
     break
   fi
 done
 [ "$alldepends" == "no" ] && continue


 # if we are testing, just print the ID we would have run
 if [ -n "$TESTONLY" ]; then
   echo "# run_pipeline $id # [$datasource $pipeline]"
 else
   # ! run_pipeline $id && err "did not succesfully finish run_pipeline $id"
   run_pipeline $id || warn "did not succesfully finish run_pipeline $id"
 fi
 
 return 0
}

## ACTUALLY DO STUFF

# get to the subjects root directory for this datasource/pipeline
PPSUBJSDIR="/Volumes/Zeus/preproc/$(basename $datasource)/$(basename $pipeline)"
[ ! -d "$PPSUBJSDIR" ] && mkdir -p $PPSUBJSDIR

cd $PPSUBJSDIR

# warp it all together
args_or_list_all_ids $@ | while read id; do
 runwithdepends $id  # &
 echo "# launched $datasource::$pipeline for $id ($(njobs)/$MAXJOBS jobs)"

 # if we only want to run one, end here
 [ -n "$ONEONLY" ] && break
 
 waitforjobs $MAXJOBS
done

echo "# all jobs forked, waiting to complete"
wait
