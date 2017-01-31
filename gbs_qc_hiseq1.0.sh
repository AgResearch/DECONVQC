#!/bin/sh
# see http://wiki.bash-hackers.org/howto/getopts_tutorial for getops tips 

function get_opts() {

help_text="
 examples : \n
 ./gbs_qc_hiseq1.0.sh -i -n -r 161216_D00390_0276_AC9PM8ANXX\n
 ./gbs_qc_hiseq1.0.sh -i -r 161216_D00390_0276_AC9PM8ANXX \n
 ./gbs_qc_hiseq1.0.sh -i -t kmer_analysis -r 161216_D00390_0276_AC9PM8ANXX \n
 ./gbs_qc_hiseq1.0.sh -i -t blast_analysis -r 161216_D00390_0276_AC9PM8ANXX \n
 ./gbs_qc_hiseq1.0.sh  -n -s SQ0317 -t blast_analysis -i -r 170106_D00390_0279_BCA81DANXX \n
 ./gbs_qc_hiseq1.0.sh  -s SQ0317 -t blast_analysis -i -r 170106_D00390_0279_BCA81DANXX \n
"

DRY_RUN=no
INTERACTIVE=no
TASK=qc
RUN=all
MACHINE=hiseq
SAMPLE=""

while getopts ":niht:r:m:s:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    i)
      INTERACTIVE=yes
      ;;
    t)
      TASK=$OPTARG
      ;;
    m)
      MACHINE=$OPTARG
      ;;
    r)
      RUN=$OPTARG
      ;;
    s)
      SAMPLE=$OPTARG
      ;;
    h)
      echo -e $help_text
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

HISEQ_ROOT=/dataset/${MACHINE}/active
BUILD_ROOT=/dataset/${MACHINE}/scratch/postprocessing
}


function check_opts() {
if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi

# check args
if [[ ( $TASK != "qc" ) && ( $TASK != "blast_analysis" ) && ( $TASK != "kmer_analysis") ]]; then
    echo "Invalid task name - must be qc , blast_analysis or kmer_analysis" 
    exit 1
fi

# machine must be miseq or hiseq 
if [[ ( $MACHINE != "hiseq" ) && ( $MACHINE != "miseq" ) ]]; then
    echo "machine must be miseq or hiseq"
    exit 1
fi

}


function echo_opts() {
    echo "run to process : $RUN"
    echo "task requested : $TASK"
    echo "dry run : $DRY_RUN"
    echo "interactive : $INTERACTIVE"
    echo "machine : $MACHINE"
    echo "sample : $SAMPLE"
}

function configure_env() {
    module load tassel/3/3.0.173 
}

function get_parameters() {
    # if the parameters file is not there get it 
    # (note that when this is called, RUN_ROOT is defined)
    PARAMETERS_FILE=$BUILD_ROOT/${RUN}.SampleProcessing.json
    if [ ! -f $PARAMETERS_FILE ]; then
       echo "$PARAMETERS_FILE is missing , it should have been generated when the run was processed - quitting"
       exit 1
    fi    
    
    if [ $INTERACTIVE == "yes" ]; then
       answer="no"
       echo "processing parameters ($PARAMETERS_FILE): "
       cat $PARAMETERS_FILE
       echo "

       OK to update these with GBS settings ? (y/n)
       "
       read answer
       if [ "$answer" != "y" ]; then
          echo "OK will not update"
       else
          $GBS_BIN/get_processing_parameters.py --json_out_file $PARAMETERS_FILE --parameter_file ${HISEQ_ROOT}/${RUN}/SampleSheet.csv --species_references_file  /dataset/hiseq/active/sample-sheets/reference_genomes.csv 
       fi


       echo "processing parameters including GBS parameters ($PARAMETERS_FILE): "
       cat $PARAMETERS_FILE
       echo "

       OK to use these parameters ? (y/n)
       "
       read answer
       if [ "$answer" != "y" ]; then
          echo "please edit $PARAMETERS_FILE and try again"
          exit 1
       fi 
    fi
}

function get_analyses() {
   my_processed_root=$1
   my_run_root=$2

   if [ -z $SAMPLE ]; then
      analysis_targets=""

      # get the sample monikers string needed by the makefile
      # this is obtained from the database
      sample_monikers=`psql -U agrbrdf -d agrbrdf -h invincible -v run=\'$RUN\' -f database/get_run_samples.psql -q`
      for sample_moniker in $sample_monikers; do
         if [[ ( $TASK == "qc" ) || ( $TASK == "kmer_analysis" ) ]]; then
            analysis_targets="$analysis_targets $my_run_root/${sample_moniker}.processed_sample/uneak/kmer_analysis/zipfian_distances.jpg"
         fi  
         if [[ ( $TASK == "qc" ) || ( $TASK == "blast_analysis" ) ]]; then
            analysis_targets="$analysis_targets $my_run_root/${sample_moniker}.processed_sample/uneak/blast_analysis/sample_blast_summary.jpg"
         fi
      done
   else
      sample_moniker=$SAMPLE
      if [[ ( $TASK == "qc" ) || ( $TASK == "kmer_analysis" ) ]]; then
         analysis_targets="$analysis_targets $my_run_root/${sample_moniker}.processed_sample/uneak/kmer_analysis/zipfian_distances.jpg"
      fi
      if [[ ( $TASK == "qc" ) || ( $TASK == "blast_analysis" ) ]]; then
         analysis_targets="$analysis_targets $my_run_root/${sample_moniker}.processed_sample/uneak/blast_analysis/sample_blast_summary.jpg"
      fi
   fi

   echo DEBUG $sample_monikers
   echo DEBUG $analysis_targets
}

get_opts $@

check_opts

echo_opts

configure_env

# from here , in line code to do the processing
PARAMETERS_FILE=$BUILD_ROOT/${RUN}.SampleProcessing.json

# get gbs parameters 
if [ ! -f $PARAMETERS_FILE ]; then
   echo "$PARAMETERS_FILE missing - please run get_processing_parameters.py (for help , ./get_processing_parameters.py -h)"
   exit 1
fi
# get blast and trimming parameters
# leaver out for now
#tagcounts_s=`$BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name gbs_tagcounts_s`


if [ $RUN == "all"  ]; then 
   echo " are you sure you want to check all runs ? (y/n)"
   read response
   if [ "$response" != "y" ]; then
      echo "OK - to process a single run, enter (e.g.)
      ./gbs_hiseq1.0.sh -r 150326_D00390_0220_BC6GKKANXX
      "
      echo "quitting"
      exit 1
   fi
   processed_run_folders=${BUILD_ROOT}/*.processed
else
   processed_run_folders=${BUILD_ROOT}/${RUN}.processed
fi

for processed_run_folder in $processed_run_folders; do
   if [ ! -d $processed_run_folder ]; then
      echo "error  - $processed_run_folder not found"
      exit 1
   fi
   run=`basename $processed_run_folder .processed`
   echo "(logging to  $BUILD_ROOT/${run}.gbs.qc.log)"

   RUN_ROOT=${BUILD_ROOT}/${run}.gbs

   # get the samples to process - will build a list in the variable analysis_targets
   get_analyses $processed_run_folder $RUN_ROOT 

   # get the parameters that control the Q/C run - e.g.
   # reference genomes , blast database to use etc
   get_parameters

   # run the task 
   MAKE_TARGET="qc"

   if [ $DRY_RUN == "yes" ]; then
      echo "****** DRY RUN ONLY ******"
      set -x
      make -n -d -f gbs_qc_hiseq1.0.mk -j 24 --no-builtin-rules machine=${MACHINE} analysis_targets="$analysis_targets" hiseq_root=$HISEQ_ROOT parameters_file=$PARAMETERS_FILE $BUILD_ROOT/$run.${MAKE_TARGET} > $BUILD_ROOT/${run}.gbs.qc.log 2>&1
      echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql"
      echo $GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
      echo "Rscript --vanilla $GBS_BIN/taxonomy_clustering.r run_name=$RUN"
      echo "$GBS_BIN/summarise_global_hiseq_reads_tags_cv.sh $RUN"
      echo "Rscript --vanilla  $GBS_BIN/tags_plots.r  run_name=$RUN"
      echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql"
      echo "$GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt"
      echo "$GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt"
   else
      set -x
      make -d -f gbs_qc_hiseq1.0.mk -j 24 --no-builtin-rules machine=${MACHINE} analysis_targets="$analysis_targets" hiseq_root=$HISEQ_ROOT parameters_file=$PARAMETERS_FILE $BUILD_ROOT/$run.${MAKE_TARGET} > $BUILD_ROOT/${run}.gbs.qc.log 2>&1
      psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql
      $GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
      Rscript --vanilla $GBS_BIN/taxonomy_clustering.r run_name=$RUN
      $GBS_BIN/summarise_global_hiseq_reads_tags_cv.sh $RUN
      Rscript --vanilla  $GBS_BIN/tags_plots.r run_name=$RUN
      psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql
      $GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt
      for species_pattern in mussell salmon deer sheep cattle ryegrass clover ; do
          $GBS_BIN/database/make_species_peacock_plots.sh $BUILD_ROOT/peacock_data.txt $species_pattern
      done
      $GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt
   fi

   # make a precis of the log file for easier reading
   #make -f gbs_hiseq1.0.mk -i --no-builtin-rules $BUILD_ROOT/${processed_run_folder}.logprecis > /dev/null 2>&1
   # make a summary of the versions of software that were run
   #make -f gbs_hiseq1.0.mk -i --no-builtin-rules versions.log 

   set +x
done

exit
