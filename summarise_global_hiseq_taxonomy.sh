#!/bin/sh

if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi

BUILD_ROOT=/dataset/hiseq/scratch/postprocessing 
THIS_RUN=$1

# ... to do - get the cumulativei list below by doing a find on pickle files 
# - will also need to add current run as an argument. Then add this to the 
# processing script - will call it after the make has finished

# find all the runs with summaries , excluding this run
runs=""
for file in `find /dataset/hiseq/scratch/postprocessing/*.processed/taxonomy_analysis -maxdepth 1 -name samples_taxonomy_table.txt -print`; do
   # e.g. /dataset/hiseq/scratch/postprocessing/141217_D00390_0214_BC4UEHACXX.processed/taxonomy_analysis/samples_taxonomy_table.txt
   dir=`dirname $file`
   dir=`dirname $dir`
   run=`basename $dir .processed`
   if [ $run != $THIS_RUN ]; then
      runs="$runs $run"
   fi
done

# add this run - we want this run's samples to be last in the file
runs="$runs $THIS_RUN"

set -x

for summary in "frequency" "information" ; do
   # summarise all hits
   outfile=$BUILD_ROOT/all_${summary}.txt
   $GBS_BIN/summarise_global_hiseq_taxonomy.py -t $summary  -o $outfile $runs
   outfile=$BUILD_ROOT/all_${summary}_xnohit.txt
   $GBS_BIN/summarise_global_hiseq_taxonomy.py -t $summary  -o $outfile -x nohit $runs  # excluding no hits 

   # make kingdom-specific files as well
   #for kingdom in "eukaryota" "bacteria"; do
   for kingdom in "eukaryota" ; do
      outfile=$BUILD_ROOT/${kingdom}_${summary}.txt
      $GBS_BIN/summarise_global_hiseq_taxonomy.py -s $kingdom -t $summary  -o $outfile $runs
      outfile=$BUILD_ROOT/${kingdom}_${summary}_xnohit.txt
      $GBS_BIN/summarise_global_hiseq_taxonomy.py -s $kingdom -t $summary  -o $outfile -x nohit $runs  # excluding no hits 
   done
done
set +x

# extract the required sample species table (sample_species.txt)
cd $BUILD_ROOT
psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql
