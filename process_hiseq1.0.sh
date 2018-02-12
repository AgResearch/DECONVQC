#!/bin/sh
#
# This the first processing step, run after the hiseq run completes (as indicated
# by the file RTAComplete.txt appearing the run folder
#
# examples : 
# ./process_hiseq1.0.sh -n -r 150515_D00390_0227_BC6JPMANXX
# ./process_hiseq1.0.sh -r 150515_D00390_0227_BC6JPMANXX

function get_opts() {

help_text="
 examples : \n
 ./process_hiseq1.0.sh -i -n -r 150515_D00390_0227_BC6JPMANXX \n
 ./process_hiseq1.0.sh -i -r 150515_D00390_0227_BC6JPMANXX \n
 ./process_hiseq1.0.sh -i -m miseq -r 171026_M02412_0043_000000000-D2N2U \n
"

DRY_RUN=no
INTERACTIVE=no
ANALYSIS=bcl2fastq
RUN=all
MACHINE=hiseq
TASK=bcl2fastq

while getopts ":niha:r:m:t:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    i)
      INTERACTIVE=yes
      ;;
    a)
      ANALYSIS=$OPTARG
      ;;
    m)
      MACHINE=$OPTARG
      ;;
    r)
      RUN=$OPTARG
      ;;
    t)
      TASK=$OPTARG
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
# check args
if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi

if [[ ( $ANALYSIS != "bcl2fastq" ) ]]; then
    echo "Invalid analysis name - must be bcl2fastq " >&2
    exit 1
fi

# machine must be miseq or hiseq 
if [[ ( $MACHINE != "hiseq" ) && ( $MACHINE != "miseq" ) ]]; then
    echo "machine must be miseq or hiseq"
    exit 1
fi

# only allow specific anlayses for specific runs
if [[ ( $TASK != "bcl2fastq" ) && ( $TASK != "dbupdate" ) ]]; then
    echo "task must be bcl2fastq or dbupdate"
    exit 1
fi

# if the machine is miseq , there needs to be a shortcut under the hiseq
# folder pointing to it. 
if [ $MACHINE == "miseq" ]; then
   if [ ! -h $CANONICAL_HISEQ_ROOT/$RUN ] ; then
      echo "please ln -s $HISEQ_ROOT/$RUN $CANONICAL_HISEQ_ROOT/$RUN "
      exit 1
   else
      HISEQ_ROOT=$CANONICAL_HISEQ_ROOT
      BUILD_ROOT=$CANONICAL_BUILD_ROOT
   fi 
fi


}


function echo_opts() {
    echo "run to process : $RUN"
    echo "analysis requested : $ANALYSIS"
    echo "dry run : $DRY_RUN"
    echo "interactive : $INTERACTIVE"
    echo "machine : $MACHINE"
}

function get_parameters() {
    # if the parameters file is not there get it 
    # (note that when this is called, RUN_ROOT is defined)
    PARAMETERS_FILE=$BUILD_ROOT/${RUN}.SampleProcessing.json
    if [ ! -f $PARAMETERS_FILE ]; then
       ./get_processing_parameters.py --parameter_file ${HISEQ_ROOT}/${RUN}/SampleSheet.csv --species_references_file  /dataset/hiseq/active/sample-sheets/reference_genomes.csv  > $PARAMETERS_FILE 
    fi    
    
    if [ $INTERACTIVE == "yes" ]; then
       answer="no"
       echo "processing parameters ($PARAMETERS_FILE): "
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


function update_database() {
   # add the run 
   echo "** adding Run **"
   set -x
   if [ $DRY_RUN == "no" ]; then
      $GBS_BIN/database/addRun.sh -r $RUN -m $MACHINE
      $GBS_BIN/database/annotateRun.sh -r $RUN -t Plot_link

   else
      $GBS_BIN/database/addRun.sh -n -r $RUN -m $MACHINE
   fi
}


get_opts $@

check_opts

echo_opts

completed_run_landmarks=$HISEQ_ROOT/$RUN/RTAComplete.txt

for completed_run_landmark in $completed_run_landmarks; do
   if [ ! -f $completed_run_landmark ]; then
      echo "error  - $completed_run_landmark not found"
      exit 1
   fi
   completed_run_folder=`dirname $completed_run_landmark`
   run=`basename $completed_run_folder`
   echo "(logging to  $BUILD_ROOT/${run}.log)"

   # check there is a sample-sheet for this run 
   if [ ! -f ${HISEQ_ROOT}/${RUN}/SampleSheet.csv ]; then
      echo "skipping $RUN (and also quitting) as no sample sheet found (looking for ${HISEQ_ROOT}/${RUN}/SampleSheet.csv)"
      exit 1
   fi

   # sanity check the sample-sheet - project name not allowed to contain 
   # spaces etc -there is a black-list in the Illumina manual.
   # this checks all on the black-list exept for , 
   # the project name and sample names are columns 3 and 10
   cat ${HISEQ_ROOT}/${RUN}/SampleSheet.csv | egrep -v "^#" | awk -F, '{print $3$10}' | egrep "[]\[?()/\\=+<>:;\"'*\^|& ]" -  > /dev/null 2>&1
   if [ $? == 0 ]; then
      echo "
      skipping $RUN (and also quitting) as sample sheet ${HISEQ_ROOT}/${RUN}/SampleSheet.csv contains illegal charaters (ref Illumina user guides)
      "
      exit 1
   fi



   RUN_ROOT=${BUILD_ROOT}/${run}.processed_in_progress
   MAPPING_FOLDER=${RUN_ROOT}/mapping_analysis_in_progress

   # get the parameters that cnotrol the Q/C run - e.g.
   # reference genomes , blast database to use etc
   get_parameters

   MAKE_TARGET="all"

   if [ $TASK == "bcl2fastq" ]; then 
      if [ $DRY_RUN == "yes" ]; then
         echo "****** DRY RUN ONLY ******"
         set -x
         make -n -d -f process_hiseq1.0.mk -j 24 --no-builtin-rules run=${RUN} machine=${MACHINE} hiseq_root=$HISEQ_ROOT $BUILD_ROOT/${run}.${MAKE_TARGET} > $BUILD_ROOT/${run}.log 2>&1
      else
         set -x
         make -d -f process_hiseq1.0.mk -j 24 --no-builtin-rules run=${RUN} machine=${MACHINE} hiseq_root=$HISEQ_ROOT $BUILD_ROOT/${run}.${MAKE_TARGET} > $BUILD_ROOT/${run}.log 2>&1
         echo ""
      fi
   elif [ $TASK == "dbupdate" ]; then
      update_database
   fi


   # make a precis of the log file for easier reading
   make -f process_hiseq1.0.mk -i --no-builtin-rules $BUILD_ROOT/${run}.logprecis > /dev/null 2>&1

   # make a summary of the versions of software that were run
   #make -f process_hiseq1.0.mk -i --no-builtin-rules versions.log 

   set +x
done

exit
