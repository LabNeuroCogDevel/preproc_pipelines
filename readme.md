redo "restPreproc" 

## organize

### Output
 `/Volumes/Zeus/preproc/$datasource/$pipe/$subj_$date`

pipes can depend on other pipes (t1 for t2)

### Configure
 `data/$datasource` 

Contains info about MR protocol for datasource
 * `SUBJECTS_DIR` FreeSurfer directory
 * `DICOM_PAT` e.g. `MR*`
 * `list_all` function to list all subject ids
 * `subj_t1` function to location of MR of subject. takes one argument: id. returns 1 folder with `$DICOM_PATT` or hdr
 * `subj_t2` function to location of MR of subject. takes one argument: id. returns n folders with `$DICOM_PATT` or hdr 
 * `subj_ref` function to locate  return ref hdr, matches length of `subj_t2`
 * `subj_physio` 

### Pipelines
`pipes/$pipe`
contains 
 * `PIPE_DEPENDS` space separated list of pipeline dependencies
 * `PIPE_VERSION` date `yyyymmdd` of last significant modification
 * `PIPE_DESC`    description of pipeline, not used but will not run without
 * `FINALOUT`     final output name, to check if complete
 * `run_pipeline` function to run pipeline given DCM folder input, optionally ref and physio.

 `run_pipeline` should make subject directories only. will be run from datasource/pipeline directory. Will have $PPSUBJSDIR avaible
