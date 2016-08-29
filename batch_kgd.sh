#!/bin/sh

if [ -z "$1" ]; then
   echo "usage : ./batch_kgd.sh run_name 
   example
   ./batch_kgd.sh 151113_D00390_0239_BC808AANXX
   "
   exit 1
fi

RUN=$1
RUN_FOLDER=/dataset/hiseq/scratch/postprocessing/${RUN}.gbs
if [ ! -d $RUN_FOLDER ]; then
   echo $RUN_FOLDER does not exist
   exit 1
fi

if [ -z "$GBS_BIN" ]; then
   echo "please set GBS_BIN"
   exit 1
fi

for sample_folder in $RUN_FOLDER/*.processed_sample; do
   echo " running ./run_kgd.sh $sample_folder/uneak/KGD"
   $GBS_BIN/run_kgd.sh $sample_folder/uneak/KGD
done

