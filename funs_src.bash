
# get script directory, usually already have this
[ -z "$SCRIPTDIR" ] && SCRIPTDIR=$(cd $(dirname $0);pwd)

# wrap up info into a string
function infobar {
 echo "[$(whoami)@$(hostname):$(pwd)#$(date +%F/%M:%H)]"
}
function whatscriptfuns {
  echo "${FUNCNAME[@]} :: ${BASH_SOURCE[@]}"
}

# exit error message
function trapmsg {
 err=$?
 [ $err -ne 0 ] && warn "$0 exited with error $err!\n$(infobar)\n[$scriptwhereami]"
}

# exit with error function
function err {
 echo "ERROR: $@" >&2 
 exit 1
}

# echo to std err
function warn {
 echo -e "$@" >&2
}

# print usage from top of file
function usage {
 echo "USAGE:" >&2
 sed -n '/USAGE/,/END USAGE/ s/^\# //p' $0 |
 sed "s:\$0:$0:g" >&2
 err "$@"
}

# test only has one input for grant functions
function wantonlyoneid {
 func=${FUNCNAME[1]}
 [ -z "$1" ] && warn "no subject id given to $func" && return 1
 [ -n "$2" ] && warn "too many subject ids given to $func ($@)" && return 1
 return 0
}

# given a root directory, a protocol directory pattern, and a dicom count
# find protocol directories with that count
function findpattdcmcnt  {
 [ -z "$3" ] && warn "$FUNCNAME wants 3 inputs, got $@" && return 1
 root=$1;    shift
 pat=$1;     shift
 dicomcnt=$1;shift

 [ ! -d "$root" ] && warn "$FUNCNAME needs a directory not $root" && return 1

 find $root -maxdepth 1 -iname "$pat" | while read d; do
   cnt=$(ls $d/MR* | wc -l)
   [ $cnt -ne $dicomcnt ] && warn "# $d has $cnt MR*s, not $dicomcnt" && continue
   echo $d
 done
 return 0
}

function checkarraycount {
 cnt=$1; shift
 [ $# -ne $cnt ] && warn "${FUNCNAME[1]}: count not exactly $cnt '$@'" && return 1
 return 0
}


## bash job control
function njobs {
 jobs -p | wc -l 
}
# optionally take maxjobs as argument, expect sleeptime to be in enviornment
function waitforjobs {
 # set defaults, maxjobs can come as an arg
 [ -n "$1" ] && MAXJOBS=$1
 [ -z $MAXJOBS ] && MAXJOBS=1
 [ -z $SLEEPTIME ] && SLEEPTIME=60

 local cnt=1
 while [ $(njobs) -ge $MAXJOBS ]; do
   echo "# $cnt @ $MAXJOBS jobs, wait ${SLEEPTIME}s | $(infobar) $(whatscriptfuns) "
   sleep $SLEEPTIME 
   let cnt++
 done
}
