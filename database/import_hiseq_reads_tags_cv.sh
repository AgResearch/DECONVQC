#!/bin/sh

if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi


BUILD_ROOT=/dataset/hiseq/scratch/postprocessing 

function collate_data() {
rm $BUILD_ROOT/gbs_yield_import_temp.dat
for file in $BUILD_ROOT/*.gbs/*.processed_sample/uneak/TagCount.csv; do
   # e.g. /dataset/hiseq/scratch/postprocessing/160623_D00390_0257_AC9B0MANXX.gbs/SQ2562.processed_sample/uneak/TagCount.csv
   # files contain 
   #sample,flowcell,lane,sq,tags,reads
   #total,C6JPMANXX,7,88,,211124459
   #good,C6JPMANXX,7,88,,202570647
   #998599,C6JPMANXX,7,88,231088,776567
   #998605,C6JPMANXX,7,88,419450,2148562

   dir=`dirname $file`
   sample=`dirname $dir`
   run=`dirname $sample`
   run=`basename $run .gbs`
   sample=`basename $sample .processed_sample`
   cat $file | awk -F, '{printf("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",run,sample,$1,$2,$3,$4,$5,$6);}' run=$run sample=$sample - >> $BUILD_ROOT/gbs_yield_import_temp.dat
done
}

function import_data() {
psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/import_hiseq_reads_tags_cv.psql
}

function update_data() {
psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/update_hiseq_reads_tags_cv.psql 
}

collate_data
import_data
update_data
