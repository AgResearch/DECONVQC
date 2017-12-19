#!/bin/sh
#
# util for "manually" re-running a plot for a run
 
module load R3env/3.3/3.3

#RUN=171214_D00390_0336_ACBG26ANXX
RUN=171016_D00390_0331_ACBG8AANXX 
GBS_BIN=/dataset/hiseq/active/bin/DECONVQC


#psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql
#$GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
Rscript --vanilla $GBS_BIN/taxonomy_clustering.r run_name=$RUN
