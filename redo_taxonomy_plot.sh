#!/bin/sh
#
# util for "manually" re-running a plot for a run
 
module load R3env/3.3/3.3

#RUN=171214_D00390_0336_ACBG26ANXX
RUN=171016_D00390_0331_ACBG8AANXX 
GBS_BIN=/dataset/hiseq/active/bin/DECONVQC
BUILD_ROOT=/dataset/hiseq/scratch/postprocessing


#psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql
#$GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
Rscript --vanilla $GBS_BIN/taxonomy_clustering.r run_name=$RUN
convert $BUILD_ROOT/euk_taxonomy_clustering_${RUN}.jpg $BUILD_ROOT/all_taxonomy_clustering_${RUN}.jpg $BUILD_ROOT/xno_taxonomy_clustering_${RUN}.jpg  -append $BUILD_ROOT/taxonomy_clustering_${RUN}.jpg
