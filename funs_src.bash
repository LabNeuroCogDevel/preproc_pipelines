
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

 [ -n "$SUBJNAMEPATT" ] && [[ ! $1 =~ $SUBJNAMEPATT ]] && warn "$1 does not look like a subject ($SUBJNAMEPATT)" && return 1
 return 0
}

# given a root directory, a protocol directory pattern, and a dicom count
# find protocol directories with that count
function findpattdcmcnt  {
 [ -z "$3" ] && warn "$FUNCNAME wants 3 inputs, got $@" && return 1
 root=$1;    shift
 pat=$1;     shift
 dicomcnt=$1;shift

 [ ! -d "$root" ] && warn "$FUNCNAME needs a directory not $root (${FUNCNAME[@]})" && return 1

 # default to dicom pattern as MR* (alternative might be *.dcm)
 [ -z "$DICOM_PAT" ] && DICOM_PAT='MR*'

 find $root -maxdepth 1 -iname "$pat" | while read d; do
   cnt=$(ls $d/$DICOM_PAT | wc -l)
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

## specify a specfic mrfolder to use for a subject
## will see if first 2 arguments match to echo folder specifed by 3rd argument
# return 1 if no match
# return 0 and echo dir of match
## in subj_t1 
## pick_mrfolder $1 "10905_20111212" axial_mprage_G2_256x192.18 && return 0
pick_mrfolder() {
 haveid=$1
 searchid=$2
 dirname=$3
 [ -z $dirname ] && warn "$FUNC_NAME: bad call. need 3 arguemnts got $@" && return 1
 if [ "$haveid" == $searchid ];then
  returndir="$MRROOT/$searchid/$dirname" 
  warn "# $searchid manually set directory to '$returndir'"
  [ ! -r "$returndir" ] && warn "explicit dir ('$returndir') DNE!" && return 1
  echo "$returndir"
  return 0
 fi

 return 1
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


# check finalout to see if we've already finished
# expect to be in PPSUBJSDIR 
# that is $id/$file is where to check for final files
# success if has final, return error otherwise
function has_finalout {
 [ -z "$FINALOUT" ] && warn "#${FUNCNAME[1]} needs to define FINALOUT" && return 1
 wantonlyoneid $@ || return 1
 id="$1"
 local alreadyfinished="yes"
 for fout in ${FINALOUT[@]}; do
   [ -r $id/$fout ] && continue

   alreadyfinished="no"
   warn "cannot find expected finalout: $(pwd)/$id/$fout"
   break
 done
 [ "$alreadyfinished" == "yes" ] && warn "# $(basename "$datasource") $(basename "$pipeline") $id already finished!" && return 0

 return 1
}

# given an id, pattern, and dicomcount
# echo the 1 directory that matches or return error
# expect dir like mrroot/ id / protocol pattern / MR*
# will check count to the number of dicoms in directory
# and return the directory that matches
# USAGE:
#  subj_mr_pat $id 'axial_mprage*' 192 || return 1
#  - find mprage directory with 192 dicoms for $id
function subj_mr_pat {
 path="$1"
 patt="$2"
 cnt="$3"
 [ -z "$MRROOT" ] && warn "MRROOT not in env!" && return 1
 [ -z "$3"      ] && warn "$FUNCNAME not given enough arguemetns" && return 1 

 mrdirs=($(findpattdcmcnt "$path" "$patt" "$cnt") )
 if ! checkarraycount 1 ${mrdirs[@]} ; then
   warn "nothing fits $path/$patt/$DICOM_PAT"  
   return 1
 fi
 echo $mrdirs
}


# find t1 (from within functional run_pipeline)
function find_t1final {
 wantonlyoneid $@ || return 1
 id="$1"

 [ -z "$PPSUBJSDIR" ] && 
   warn "need PPSUBJSDIR (root of preprocessed subjects) to be defined" && return 1

 # need t1 should be done b/c of depends
 mpragedir=$PPSUBJSDIR/../MHT1_2mm/$id
 [ ! -d $mpragedir ] && warn "# cannot find $mpragedir" && return 1
 
 # should have bet and warp outputs
 bet=$mpragedir/mprage_bet.nii.gz
 warp=$mpragedir/mprage_warpcoef.nii.gz
 [ ! -r "$bet"  ] && warn "# cannot read bet '$bet'" && return 1
 [ ! -r "$warp" ] && warn "# cannot read warp '$warp'" && return 1
 echo "$bet $warp"
}
function find_t1ant {
 wantonlyoneid $@ || return 1
 id="$1"

 [ -z "$PPSUBJSDIR" ] && 
   warn "need PPSUBJSDIR (root of preprocessed subjects) to be defined" && return 1

 # need t1 should be done b/c of depends
 mpragedir=$PPSUBJSDIR/../ANT_2mm/$id
 [ ! -d $mpragedir ] && warn "# cannot find $mpragedir" && return 1
 
 # should have bet and warp outputs
 bet=$mpragedir/mprage_bet.nii.gz
 warp=$mpragedir/MNIT11Warp.nii.gz # MNIT11InverseWarp.nii.gz MNIT1Warped.nii.gz ...
 [ ! -r "$bet"  ] && warn "# cannot read bet '$bet'" && return 1
 [ ! -r "$warp" ] && warn "# cannot read warp '$warp'" && return 1
 echo "$bet $warp"
}

# find field maps (from within functional run_pipeline)
# return path to each fm reconstructed
function find_fm {
 wantonlyoneid $@ || return 1
 id="$1"
 [ -z "$PPSUBJSDIR" ] && 
   warn "need PPSUBJSDIR (root of preprocessed subjects) to be defined" && return 1

 magphase=""


 # MHFM
 #fmdir=$PPSUBJSDIR/../MHFM/$id/
 # meh -- still tries to make from MRs
 #[ ! -r $fmdir ] && warn "# missing fm dir $fmdir for $id" && return 1
 #for fm in magnitude phase; do
 # locfile=$(find $fmdir -iname ".fieldmap_$fm"|sed 1q)
 # [ -z "$locfile" ] && warn "# missing $fm fm location: $fmdir/.fieldmap_$fm*" && return 1
 # fmfile="$fmdir/$(cat $locfile).nii.gz"
 # [ ! -r "$fmfile" ]  && warn "# missing fm file: $fmfile" && return 1
 # 
 # magphase="$magphase $fmfile"
 #done


 # cpFM
 fmdir=$PPSUBJSDIR/../cpFM/$id/
 for fm in mag phase; do
  d=$fmdir/mr$fm
  [ ! -d $d ] && warn "# missing fm dir $d for $id" && return 1
  [ $(find $d -iname 'MR*' -maxdepth 1 |wc -l) -lt 0 ] && warn "# no MR* in fm dir $d for $id" && return 1
  
  magphase="$magphase $d/MR\*"
 done

 # echo it
 echo $magphase
}


# do we still have a lock file?
# has enough time passed to clear the lock
lock_time_compare() {
 local MAXWAITHOURS=4
 local lockfile="$1"
 [ ! -r $lockfile ] && return 0
 # from HM prepair_fieldmaps
 local now=$(date +%s)
 local ctime=$(cat $lockfile)

 [[ ! $ctime =~ [0-9]? ]] && warn "# malformed lock file '$lockfile', remove me"

 if [ "$((( $now-$ctime )))" -gt "$((($MAXWAITHOURS*60*60)))" ]; then
    warn "# it's been over 4 hours, removing $lockfile" 
    rm $lockfile 
    return 0
 fi

 return 1
}

# write a lock file
# if we have one already, wait for it to clear
# clear it if it's over 4 hours old
check_write_lock() {
 [ -z "$1" ] && warn "$FUNCNAME need file to lock!" && return 1

 lock_time_compare "$1" || echo "have lock $1, waiting for job to finish"
 while ! lock_time_compare "$1" ; do
   sleep 10
 done

 date +%s > $lockfile
}


# link in all files from a diretory($1) not newer than a file ($2)
link_prev_pipe() {
 [ -z "$2" ] && warn "$FUNCNAME needs 2 args: folder and not newer file" && return 1
 local prevpipedir="$1"
 local lastgoodfile="$2"
 [ ! -d "$prevpipedir" ] && warn "$FUNCNAME: previous pipe directory '$prevpipedir' does not exist" && return 1
 [ ! -e "$lastgoodfile" ] && warn "$FUNCNAME: last good file '$lastgoodfile' does not exist" && return 1

 # clean up path: remove eg ../..
 prevpipedir=$(realpath -s $prevpipedir)

 # link in previous run
 find "$prevpipedir" -not -newer "$lastgoodfile" -maxdepth 1 | while read f; do
  # have we already linked in the file?
  [ -e "$(basename "$f")" ] && continue #&& warn "already have $f" && continue
  # link in file
  ln -s "$f" ./ 
  # make sure we dont write to this file
  [ -w "$f" ] && chmod -w "$f"
 done
}

## test/set permissions
test_folder_write(){
 [ ! -w ./ ] && warn "cannot write to $(pwd): $(ls -ld $(pwd))" && return 1
 return 0
}
allow_group_write(){
  find -maxdepth 1 -type f | xargs chmod g+w 
}

file_exists_test(){
 [ -z "$1" ] && echo "$FUNCNAME needs a file to check" && return 1
 f=$1
 [ ! -r "$f" ] && warn "(${FUNCNAME[1]}) cannot find: $f " && return 1
 echo "$f"
 return 0
}

# take dicom pattern and make it a compressed nifti
# dimon_niigz 'MR*' output.nii.gz
dimon_niigz(){
 # remove .nii or .nii.gz
 out=$(basename $1 .nii)
 out=$(basename $out .nii.gz)

 patt=$2
 Dimon -infile_prefix ${2} \
       -GERT_Reco \
       -dicom_org \
       -sort_by_acq_time \
       -gert_create_dataset \
       -gert_to3d_prefix ${1} \
       -quit || return 1
 gzip $1.nii || return 1
}

# translate e.g. 10192_20140223 to $BIDSROOT/sub-10192/20140223
# expect BIDSROOT to be defined in source
ld8_to_bids(){
 [ -z "$BIDSROOT" ] && warn "BIDSROOT is not defined!" && return 1
 wantonlyoneid $@ || return 1
 id="$1"
 lunadate=$1
 luna=${lunadate%%_*}
 vdate=${lunadate##*_}
 dir=$BIDSROOT/sub-$luna/$vdate
 [ -z "$dir" ] && warn "subj bids dir '$dir' DNE!" && return 1
 echo $dir

}
