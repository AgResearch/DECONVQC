#!/bin/bash
#
# sometimes need to run the mapping preview "manually"
# - define RUN as below and then execute
#

#RUN=171208_D00390_0334_BCBE4WANXX
#RUN=171121_D00390_0333_ACBG2FANXX
RUN=180320_D00390_0353_ACC4MTANXX 
DIR=/dataset/hiseq/scratch/postprocessing/${RUN}.processed/mapping_preview 


export HPC_RESOURCE=local
mkdir -p $DIR
module load samtools14_env/1.0/1.0 
cd $DIR ; $GBS_BIN/run_mapping_preview.sh $RUN $DIR  > $DIR/run_mapping_preview.rerun.log 2>&1


