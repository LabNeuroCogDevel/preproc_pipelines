#!/usr/bin/env bash
set -e
trap 'e=$?; [ $e -ne 0 ] && echo "$0 exited in error"' EXIT

#
# regress nuis. without bandpassing for PNC and Reward_Rest
# for MJ 20180322
# WF20180403 -- change path to Finn for PNC to get missing 34

## two datasources to extend
#  Reward: /Volumes/Phillips/Finn/Reward_Rest/subjs/
#  PNC:    /Volumes/Zeus/preproc/PNC_rest/MHRest_ICAaroma/

# reg file like: /Volumes/Zeus/preproc/reward_rest/MHRest_aroma/10629_20120317/rest/nuisance_regressors_withgs.txt
reward_loc="/Volumes/Zeus/preproc/reward_rest/MHRest_aroma/*/rest/"

for f in {$reward_loc,$pnc_loc}/naswdktm_restepi_5.nii.gz; do
  cd $(dirname $f)
  pwd

  # skip if already have
  reg_outfname="grnaswdktm_tproject_20180906.nii.gz"
  [ -r "$reg_outfname" ] && continue

  [ ! -r wktm_restepi_98_2_mask_dil1x_templateTrim.nii.gz ] && \
     echo "$(pwd): no mask" && continue
  [ ! -r nuisance_regressors_withgs.txt ] && \
     echo "$(pwd): no reg file" && continue
  
  # set tr: PNC=3; reward=1.5
  dt=0
  [[ $f =~ PNC ]] && dt=3
  [[ $f =~ reward_rest ]] && dt=1.5
  [ $dt == "0" ] && echo "$(pwd): unknown tr" && continue


  echo
  echo $f

  3dTproject -overwrite \
      -input "naswdktm_restepi_5.nii.gz" \
      -mask "wktm_restepi_98_2_mask_dil1x_templateTrim.nii.gz" \
      -ort nuisance_regressors_withgs.txt \
      -dt $dt \
      -prefix "$reg_outfname" 
done
