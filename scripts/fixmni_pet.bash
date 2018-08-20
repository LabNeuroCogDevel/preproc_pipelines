#!/usr/bin/env bash
export REDOWARP=1
source ../funs_src.bash # get fixto1809c
# similiar to /Volumes/Phillips/mMR_PETDA/scripts/99_warp_to_18_09c.bash
for preproc in ../data/pet_frog/MHTask_pet/1*_2*/[1-6]_*/{nfswudktm_func_5.nii.gz,wudktm_func.nii.gz} \
               ../data/petrest_{rac[12],dtbz}/MHRest_FM_ica/1*_2*/{brnaswudktm_func_4.nii.gz,wudktm_func.nii.gz}; do
 fixto1809c $preproc &
 waitforjobs 20
done
wait
