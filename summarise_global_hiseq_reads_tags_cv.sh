#!/bin/sh

GBS_BIN=/dataset/hiseq/active/bin/hiseq_pipeline
BUILD_ROOT=/dataset/hiseq/scratch/postprocessing 

THIS_RUN=$1
# find all the runs with summaries (excluding this run)
runs=""
summaries=""
set -x
for file in $BUILD_ROOT/*.gbs/*.processed_sample/uneak/TagCount.csv; do
   # e.g. /dataset/hiseq/scratch/postprocessing/160623_D00390_0257_AC9B0MANXX.gbs/SQ2562.processed_sample/uneak/TagCount.csv
   dir=`dirname $file`
   dir=`dirname $dir`
   dir=`dirname $dir`
   run=`basename $dir .gbs`
   if [ $run != $THIS_RUN ]; then 
      # incude if not already included
      echo $runs | grep -q $run 2>/dev/null
      if [ $? != 0 ]; then 
         runs="$runs $run"
         summaries="$summaries ${run}.tag_count_summaries.txt"
      fi
   fi
done

# add this run  (we want this run to occurr last in the file)
runs="$runs $THIS_RUN"
summaries="$summaries ${THIS_RUN}.tag_count_summaries.txt"

echo "summarise_global_hiseq_reads_tags_cv.sh: the following runs are included:"
echo $runs

# first (re)calculate summaries for each run 
for run in $runs; do
   if [ -d $BUILD_ROOT/${run}.gbs ]; then
   args=""
   tag_count_summaries=`find $BUILD_ROOT/${run}.gbs -name "TagCount.csv" -print`
   for file in $tag_count_summaries; do
      args="$args $file"
   done
   if [ ! -z "$args" ]; then
      rm $BUILD_ROOT/${run}.tag_count_summaries.txt   # maybe delete this one day
      if [ ! -f $BUILD_ROOT/${run}.tag_count_summaries.txt ]; then
         echo "summarising to $BUILD_ROOT/${run}.tag_count_summaries.txt"
         $GBS_BIN/summarise_read_and_tag_counts.py -o $BUILD_ROOT/${run}.tag_count_summaries.txt $args
      else
         echo "skipping $BUILD_ROOT/${run}.tag_count_summaries.txt , already done"
      fi
   else
      echo "(no tag count summaries found under $BUILD_ROOT/${run}.gbs )"
   fi
   else
      echo "(skipping ${run} - no gbs folder found)"
   fi
done

# now concatenate those to obtain a single summary (with THIS_RUN last in the file)
cd $BUILD_ROOT
cat $summaries  > all_tag_count_summaries.txt.tmp
head -1 all_tag_count_summaries.txt.tmp > all_tag_count_summaries.txt
egrep -v '^flowcell' all_tag_count_summaries.txt.tmp >> all_tag_count_summaries.txt
set +x
