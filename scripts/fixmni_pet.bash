#!/usr/bin/env bash
cd $(dirname $0)
export REDOWARP="" # dont redo warps, skip if exists
source ../funs_src.bash # get fixto1809c

# similiar to /Volumes/Phillips/mMR_PETDA/scripts/99_warp_to_18_09c.bash
for preproc in ../data/pet_frog/MHTask_pet/1*_2*/[1-6]_*/{nfswudktm_func_5.nii.gz,wudktm_func.nii.gz} \
               ../data/petrest_{rac[12],dtbz}/MHRest_FM_ica/1*_2*/{brnaswudktm_func_4.nii.gz,wudktm_func.nii.gz}; do
 fixto1809c $preproc &
 sleep .1
 waitforjobs 20
done
wait


#export REDOWARP=1
for mask in ../data/{pet_frog/MHTask_pet/1*_2*/[1-6]_*/,petrest_{rac[12],dtbz}/MHRest_FM_ica/1*_2*/}subject_mask.nii.gz; do
 fixto1809c $mask &
 sleep .1 
 waitforjobs 20
done
wait
