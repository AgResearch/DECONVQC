#!/bin/sh
#
# this does a GBS Q/C run on the (GBS related) hiseq output.
# it is run after process_hiseq.sh 
# 

function get_opts() {

help_text="
 examples : \n
 ./gbs_hiseq1.0.sh -i -n -r 150925_D00390_0235_BC6K0YANXX\n
 ./gbs_hiseq1.0.sh -i -n -t db_update -r 151124_D00390_0240_AC88WPANXX\n
 ./gbs_hiseq1.0.sh -i -n -t annotation -r 151124_D00390_0240_AC88WPANXX\n
 ./gbs_hiseq1.0.sh -i -r 161005_D00390_0268_AC9NRJANXX -s SQ2592,SQ2593\n
 ./gbs_hiseq1.0.sh -i -t db_update -r 171026_M02412_0043_000000000-D2N2U -m miseq \n
 ./gbs_hiseq1.0.sh -i -r 180222_D00390_0347_ACC8WAANXX -k # re-use targets (e.g. can edit *.gbs_temp to remove a problematic cohort)\n
"

DRY_RUN=no
INTERACTIVE=no
TASK=uneak
RUN=all
MACHINE=hiseq
SAMPLE=""
REUSE_TARGETS="no"

while getopts ":nikht:r:m:s:e:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    k)
      REUSE_TARGETS=yes
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

CANONICAL_HISEQ_ROOT=/dataset/hiseq/active
CANONICAL_BUILD_ROOT=/dataset/hiseq/scratch/postprocessing

}


function check_opts() {
if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi

# check args
if [[ ( $TASK != "uneak" )  && ( $TASK != "all" )  && ( $TASK != "uneak_and_db_update" ) && ( $TASK != "db_update" ) && ( $TASK != "annotation" )]]; then
    echo "Invalid task name - must be uneak, all, uneak_and_db_update, db_update or annotation" 
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

# if the machine is miseq , there needs to be a shortcut under the hiseq
# folder pointing to it.
if [ $MACHINE == "miseq" ]; then
   if [ ! -h $CANONICAL_HISEQ_ROOT/$RUN ] ; then
      echo "error could not find $CANONICAL_HISEQ_ROOT/$RUN "
      exit 1
   elif [ ! -d $CANONICAL_BUILD_ROOT/${RUN}.processed ]; then 
      echo "error could not find $CANONICAL_BUILD_ROOT/${RUN}.processed"
      exit 1
   else
      HISEQ_ROOT=$CANONICAL_HISEQ_ROOT
      BUILD_ROOT=$CANONICAL_BUILD_ROOT
   fi
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


function get_samples() {
   set -x
   if [ -z $SAMPLE ]; then
      sample_monikers=`psql -U agrbrdf -d agrbrdf -h invincible -v run=\'$RUN\' -f database/get_run_samples.psql -q`
   else
      sample_monikers=$SAMPLE
   fi

   echo DEBUG $sample_monikers
   set +x
}


function get_targets() {
   if [ $TASK != "uneak" ]; then
      echo "Error - don't know how to make targets for task $TASK"
      exit 1
   fi
   set -x
   my_run_root=$2

   if [ -z $SAMPLE ]; then
      sample_targets=""

      # get the sample monikers string needed by the makefile
      # this is obtained from the database
      sample_monikers=`psql -U agrbrdf -d agrbrdf -h invincible -v run=\'$RUN\' -f database/get_run_samples.psql -q`
      for sample_moniker in $sample_monikers; do
         sample_targets="$sample_targets $my_run_root/${sample_moniker}.processed_sample"

         if [ $REUSE_TARGETS != "yes" ]; then 
            mkdir -p $RUN_TEMP/${sample_moniker}/uneak_cohorts
            cohorts=`$GBS_BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name cohorts  --sample $sample_moniker`
            for cohort in $cohorts; do
               echo "" > $RUN_TEMP/${sample_moniker}/uneak_cohorts/$cohort
            done
         fi

      done
   else
      sample_monikers=`echo $SAMPLE | sed 's/,/ /g' -`
      sample_targets=""
      for sample_moniker in $sample_monikers; do
         sample_targets="$sample_targets $my_run_root/${sample_moniker}.processed_sample"
         
         if [ $REUSE_TARGETS != "yes" ]; then 
            mkdir -p $RUN_TEMP/${sample_moniker}/uneak_cohorts
            cohorts=`$GBS_BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name cohorts  --sample $sample_moniker`
            for cohort in $cohorts; do
               echo "" > $RUN_TEMP/${sample_moniker}/uneak_cohorts/$cohort
            done
         fi

      done
   fi

   echo DEBUG $sample_monikers
   echo DEBUG $sample_targets
   set +x
}


function update_database() {
   processed_folder=$1
   add_run
   get_samples $processed_folder $RUN_ROOT
   import_keyfiles
   update_fastq_locations
   # no longer do this
   #extract_keyfiles
}

function add_run() {
   # add the run 
   echo "** adding Run **"
   set -x
   if [ $DRY_RUN == "no" ]; then
      $GBS_BIN/database/addRun.sh -r $RUN -m $MACHINE
   else
      $GBS_BIN/database/addRun.sh -n -r $RUN -m $MACHINE
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
            echo "error !! updateFastqLocations.sh  exited with $? for $sample_moniker - continuing to attempt other samples "
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
   RUN_TEMP=${BUILD_ROOT}/${run}.gbs_temp
   if [ $REUSE_TARGETS !=  "yes" ]; then
      rm -rf $RUN_TEMP
   fi

   # if requested, update the database - i.e. import run and keyfiles 
   if [[ ( $TASK == "uneak_and_db_update" ) || ( $TASK == "db_update" ) ]]; then 
      update_database $processed_run_folder
   fi
  
   if [ $TASK == "db_update" ] ; then
      exit 0
   fi

   # get the parameters that control the Q/C run - e.g.
   # reference genomes , blast database to use etc
   get_parameters

   if [ $TASK != "annotation" ]; then 
      get_targets $processed_run_folder $RUN_ROOT
   fi


   # run the task 
   MAKE_TARGET="all"

   if [ $TASK != "all" ]; then

      if [[ ( $TASK == "uneak" ) || ( $TASK == "uneak_and_db_update" ) ]]; then
         set -x
         MAKE_TARGET="uneak"
      elif [  $TASK != "annotation" ] ; then 
         echo "Invalid task name - must be uneak , uneak_and_db_update or annotation" 
         exit 1
      fi
      set +x
   fi


   function post_make() {
      if [ $DRY_RUN == "yes" ]; then
         echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql"
         echo "$GBS_BIN/summarise_global_hiseq_reads_tags_cv.sh $RUN"
         echo "Rscript --vanilla  $GBS_BIN/tags_plots.r  run_name=$RUN"
         echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql"
         echo "$GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt"
         for species_pattern in mussel salmon deer sheep cattle ryegrass clover ; do
            echo "$GBS_BIN/database/make_species_peacock_plots.sh $BUILD_ROOT/peacock_data.txt $species_pattern"
         done
         echo "$GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt"
         echo "$GBS_BIN/database/annotateRun.sh -r $RUN "
         echo "$GBS_BIN/database/import_hiseq_reads_tags_cv.sh -r $RUN"
         echo "$GBS_BIN/database/import_kgd_stats.sh -r $RUN"
      else
         psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql
         $GBS_BIN/summarise_global_hiseq_reads_tags_cv.sh $RUN
         Rscript --vanilla  $GBS_BIN/tags_plots.r run_name=$RUN
         psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql
         $GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt
         for species_pattern in mussel salmon deer sheep cattle ryegrass clover ; do
            $GBS_BIN/database/make_species_peacock_plots.sh $BUILD_ROOT/peacock_data.txt $species_pattern
         done
         $GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt
         $GBS_BIN/database/annotateRun.sh -r $RUN
         $GBS_BIN/database/import_hiseq_reads_tags_cv.sh -r $RUN
         $GBS_BIN/database/import_kgd_stats.sh -r $RUN
      fi

      # make a precis of the log file for easier reading
      #make -f gbs_hiseq1.0.mk -i --no-builtin-rules $BUILD_ROOT/${processed_run_folder}.logprecis > /dev/null 2>&1
      # make a summary of the versions of software that were run
      #make -f gbs_hiseq1.0.mk -i --no-builtin-rules versions.log

   }

   if [ $DRY_RUN == "yes" ]; then
      echo "****** DRY RUN ONLY ******"
      if [ $TASK == "annotation" ]; then
         post_make
      else
         make -n -d -f gbs_hiseq1.0.mk -j 24 --no-builtin-rules machine=${MACHINE} processed_samples="$sample_targets" hiseq_root=$HISEQ_ROOT parameters_file=$PARAMETERS_FILE run_temp=$RUN_TEMP run_name=$RUN $BUILD_ROOT/$run.${MAKE_TARGET} > $BUILD_ROOT/${run}.gbs.log 2>&1
      fi
   else
      set -x
      if [ $TASK == "annotation" ]; then
         post_make
      else
         make -d -f gbs_hiseq1.0.mk -j 24 --no-builtin-rules machine=${MACHINE} processed_samples="$sample_targets" hiseq_root=$HISEQ_ROOT parameters_file=$PARAMETERS_FILE run_temp=$RUN_TEMP run_name=$RUN $BUILD_ROOT/$run.${MAKE_TARGET} > $BUILD_ROOT/${run}.gbs.log 2>&1
      fi
      if [ $? != 0 ]; then
         echo "(warning non-zero exit status from make)"
         exit 1
      fi
   fi

   # make a precis of the log file for easier reading
   #make -f gbs_hiseq1.0.mk -i --no-builtin-rules $BUILD_ROOT/${processed_run_folder}.logprecis > /dev/null 2>&1
   # make a summary of the versions of software that were run
   #make -f gbs_hiseq1.0.mk -i --no-builtin-rules versions.log 

   set +x
done

exit
