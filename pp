#!/usr/bin/env bash

## USAGE
# $0 grant pipeline
# 
#  run preprocessing pipeline on grant data
#   - grant is a file in grants
#   - pipeline is a file in pipelines
#
## END USAGE

scriptdir=$(cd $(dirname $0);pwd)
source $scriptdir/funs_src.bash

[ -z "$2" ] && usage "need two arguments!"

# we can specify grant and pipeline as files
# but if we didn't, check inisde a subdirectory
[ ! -r $grant    ] && grant="$scriptdir/grants/$1"
[ ! -r $pipeline ] && pipeline="$scriptdir/pipes/$2"

# before we go on, make sure we have a grant and pipeline file
[ ! -r "$grant"    ] && usage "cannot read grant ($1) file $grant"
[ ! -r "$pipeline" ] && usage "cannot read pipeline ($2) file $pipeline"

# get the goodies inside each file
source $grant
source $pipeline

## we want to take the arguements as ids
## or use the list_all function from grant

# get grant and pipeline off the arg list
shift; shift;

# def function to pick which to use
function args_or_list_all_ids {
  if [ -z "$1" ]; then
   list_all
  else
   for id in $@; do echo $id; done
  fi
}


# set the exit trap so we when we die 
trap trapmsg EXIT

# get to the subjects root directory for this grant/pipeline
PPSUBJSDIR="/Volumes/Zeus/preproc/$(basename $grant)/$(basename $pipeline)"
[ ! -d $PPSUBJSDIR] && mkdir -p $PPSUBJSDIR
cd $PPSUBJSDIR

# MEAT OF WRAPPER
args_or_list_all_ids $@ | while read id; do
 [ -r $id/$FINALOUT ] && warn "$id already finished!" && continue
 # make sure all dependencies are run
 for depend in $DEPENDS; do
   $0 $grant $depend $id
 done

 run_pipeline $id
done

