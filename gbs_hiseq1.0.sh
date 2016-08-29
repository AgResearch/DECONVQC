#!/bin/sh
# see http://wiki.bash-hackers.org/howto/getopts_tutorial for getops tips 

function get_opts() {

help_text="
 examples : \n
 ./gbs_hiseq1.0.sh -i -n -r 150925_D00390_0235_BC6K0YANXX\n
 ./gbs_hiseq1.0.sh -i -n -t db_update -r 151124_D00390_0240_AC88WPANXX\n
"

DRY_RUN=no
INTERACTIVE=no
TASK=uneak
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
GBS_BIN=/dataset/hiseq/active/bin/hiseq_pipeline
export GBS_BIN
}


function check_opts() {
# check args
if [[ ( $TASK != "uneak" )  && ( $TASK != "all" )  && ( $TASK != "uneak_and_db_update" ) && ( $TASK != "db_update" ) ]]; then
    echo "Invalid task name - must be uneak, all, uneak_and_db_update, db_update " 
    exit 1
fi

# only allow specific anlayses for specific runs
if [[ ( $TASK != "all" ) && ( $RUN == "all" ) ]]; then
    echo "sorry , can't run specific task on all runs - please specify a run name for this"
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
          $GBS_BIN/get_processing_parameters.py --parameter_file ${HISEQ_ROOT}/${RUN}/SampleSheet.csv --species_references_file  /dataset/hiseq/active/sample-sheets/reference_genomes.csv   > $PARAMETERS_FILE
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

function get_samples() {
   # get the sample monikers string needed by the makefile
   # this is obtained from the sample list files generated by the hiseq processing.
   # e.g.  /dataset/hiseq/scratch/postprocessing/141217_D00390_0214_BC4UEHACXX.processed
   # - each list file contains a list of fastq files
   # 7 -rw-rw-r--  1 mccullocha hiseq_users 168 Sep 25 09:51 Sample_SQ0033.list
   # 7 -rw-rw-r--  1 mccullocha hiseq_users 168 Sep 25 09:51 Sample_SQ0018.list
   # 7 -rw-rw-r--  1 mccullocha hiseq_users 168 Sep 25 09:51 Sample_SQ0023.list
   # etc  7 -rw-rw-r--  1 mccullocha hiseq_users 168 Sep 25 09:51 Sample_SQ0024.list

   my_processed_root=$1
   my_run_root=$2
   sample_targets=""
   sample_monikers=""
   # this will just look like SQ0012 SQ0013 etc
   for sample_fastq_list in $my_processed_root/*.list; do
      echo "found ====>" $sample_fastq_list
      sample_target_moniker=`basename $sample_fastq_list .list`
      if [[ ( -z $SAMPLE ) || ( Sample_$SAMPLE == $sample_target_moniker ) ]]; then
         echo "adding $sample_target_moniker"
         sample_target_moniker=`echo $sample_target_moniker | sed 's/Sample_//g'`
         sample_monikers="$sample_monikers $sample_target_moniker"
         sample_targets="$sample_targets $my_run_root/${sample_target_moniker}.processed_sample"
      fi
   done
}

function update_database() {
   add_run
   import_keyfiles
   update_fastq_locations
   extract_keyfiles
}

function add_run() {
   # add the run 
   echo "** adding Run **"
   set -x
   if [ $DRY_RUN == "no" ]; then
      $GBS_BIN/database/addRun.sh -r $RUN
   else
      $GBS_BIN/database/addRun.sh -n -r $RUN
   fi
}

function import_keyfiles() {
   # import the keyfiles
   echo "** importing keyfiles **"
   set -x
   for sample_moniker in $sample_monikers; do
      if [ $DRY_RUN == "no" ]; then
         $GBS_BIN/database/importOrUpdateKeyfile.sh -k $sample_moniker -s $sample_moniker
      else
         $GBS_BIN/database/importOrUpdateKeyfile.sh -n -k $sample_moniker -s $sample_moniker
      fi
      if [ $? != "0" ]; then
          echo "importOrUpdateKeyfile.sh  exited with $? - quitting"
          exit 1
      fi
   done
}

function update_fastq_locations() {
   # update the fastq locations 
   echo "** updating fastq locations **"
   set -x
   for sample_moniker in $sample_monikers; do
      # to do : add a check that there is only one fcid - process not tested for 
      # a sample spread over different flowcells
      flowcell_moniker=`$GBS_BIN/database/get_flowcellid_from_database.sh $RUN $sample_moniker`
      flowcell_lanes=`$GBS_BIN/database/get_lane_from_database.sh $RUN $sample_moniker`
      for flowcell_lane in $flowcell_lanes; do
         echo "processing lane '${flowcell_lane}'"
         if [ $DRY_RUN == "no" ]; then
            $GBS_BIN/database/updateFastqLocations.sh -s $sample_moniker -k $sample_moniker -r $RUN -f $flowcell_moniker -l $flowcell_lane 
         else
            $GBS_BIN/database/updateFastqLocations.sh -n -s $sample_moniker -k $sample_moniker -r $RUN -f $flowcell_moniker -l $flowcell_lane 
         fi
         if [ $? != "0" ]; then
            echo "updateFastqLocations.sh  exited with $? - quitting"
            exit 1
         fi
      done
   done
}

function extract_keyfiles() {
   # extract the updated keyfiles
   echo "** extracting keyfiles **"
   set -x
   for sample_moniker in $sample_monikers; do
      if [ $DRY_RUN == "no" ]; then
         $GBS_BIN/database/extractKeyfile.sh -s ${sample_moniker} -k ${sample_moniker}.txt 
      else
         $GBS_BIN/database/extractKeyfile.sh -n -s ${sample_moniker} -k ${sample_moniker}.txt 
      fi
      if [ $? != "0" ]; then
          echo "extractKeyfile.sh exited with $? - quitting"
          exit 1
      fi
   done
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
   echo "(logging to  $BUILD_ROOT/${run}.gbs.log)"

   RUN_ROOT=${BUILD_ROOT}/${run}.gbs_in_progress

   # get the samples to process - will build a list in the variable sample_targets
   get_samples $processed_run_folder $RUN_ROOT 

   # if requested, update the database - i.e. import run and keyfiles 
   if [[ ( $TASK == "uneak_and_db_update" ) || ( $TASK == "db_update" ) ]]; then 
      update_database
   fi
  
   if [ $TASK == "db_update" ] ; then
      exit 0
   fi

   # get the parameters that control the Q/C run - e.g.
   # reference genomes , blast database to use etc
   get_parameters

   # run the task 
   MAKE_TARGET="all"

   if [ $TASK != "all" ]; then

      if [[ ( $TASK == "uneak" ) || ( $TASK == "uneak_and_db_update" ) ]]; then
         set -x
         MAKE_TARGET="uneak"
      else
         echo "Invalid task name - must be uneak or uneak_and_db_update" 
         exit 1
      fi
      set +x
   fi

   if [ $DRY_RUN == "yes" ]; then
      echo "****** DRY RUN ONLY ******"
      set -x
      make -n -d -f gbs_hiseq1.0.mk -j 24 --no-builtin-rules machine=${MACHINE} processed_samples="$sample_targets" hiseq_root=$HISEQ_ROOT parameters_file=$PARAMETERS_FILE $BUILD_ROOT/$run.${MAKE_TARGET} > $BUILD_ROOT/${run}.gbs.log 2>&1
      echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql"
      echo $GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
      echo "Rscript --vanilla $GBS_BIN/bacterial_contamination_plots.r"
      echo "Rscript --vanilla $GBS_BIN/taxonomy_clustering.r"
      echo "$GBS_BIN/summarise_global_hiseq_reads_tags_cv.sh $RUN"
      echo "Rscript --vanilla  $GBS_BIN/tags_plots.r"
      echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql"
      echo "$GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt"
      echo "$GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt"
   else
      set -x
      make -d -f gbs_hiseq1.0.mk -j 24 --no-builtin-rules machine=${MACHINE} processed_samples="$sample_targets" hiseq_root=$HISEQ_ROOT parameters_file=$PARAMETERS_FILE $BUILD_ROOT/$run.${MAKE_TARGET} > $BUILD_ROOT/${run}.gbs.log 2>&1
      psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql
      $GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
      Rscript --vanilla $GBS_BIN/bacterial_contamination_plots.r
      Rscript --vanilla $GBS_BIN/taxonomy_clustering.r
      $GBS_BIN/summarise_global_hiseq_reads_tags_cv.sh $RUN
      Rscript --vanilla  $GBS_BIN/tags_plots.r
      psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql 
      $GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt
      $GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt
   fi

   # make a precis of the log file for easier reading
   #make -f gbs_hiseq1.0.mk -i --no-builtin-rules $BUILD_ROOT/${processed_run_folder}.logprecis > /dev/null 2>&1
   # make a summary of the versions of software that were run
   #make -f gbs_hiseq1.0.mk -i --no-builtin-rules versions.log 

   set +x
done

exit
