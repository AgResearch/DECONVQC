#!/bin/sh
# see http://wiki.bash-hackers.org/howto/getopts_tutorial for getops tips 
# examples : 
# ./process_hiseq1.0.sh -n -r 150515_D00390_0227_BC6JPMANXX
# ./process_hiseq1.0.sh -n -a mapping -r 150515_D00390_0227_BC6JPMANXX
# ./process_hiseq1.0.sh -r 150515_D00390_0227_BC6JPMANXX
# ./process_hiseq1.0.sh -a contamination -r 150515_D00390_0227_BC6JPMANXX

function get_opts() {

help_text="
 examples : \n
 ./process_hiseq1.0.sh -i -n -r 150515_D00390_0227_BC6JPMANXX \n
 ./process_hiseq1.0.sh -i -n -a mapping -r 150515_D00390_0227_BC6JPMANXX \n
 ./process_hiseq1.0.sh -i -r 150515_D00390_0227_BC6JPMANXX \n
 ./process_hiseq1.0.sh -i -a contamination -r 150515_D00390_0227_BC6JPMANXX \n
 ./process_hiseq1.0.sh -i -a bcl2fastq -r 150515_D00390_0227_BC6JPMANXX \n
"

DRY_RUN=no
INTERACTIVE=no
ANALYSIS=all
RUN=all
MACHINE=hiseq

while getopts ":niha:r:m:" opt; do
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
# check args
if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi

if [[ ( $ANALYSIS != "all" ) && ( $ANALYSIS != "mapping" ) && ( $ANALYSIS != "contamination" )  && ( $ANALYSIS != "bcl2fastq" ) ]]; then
    echo "Invalid analysis name - must be mapping , contamination or all " >&2
    exit 1
fi

# only allow specific anlayses for specific runs
if [[ ( $ANALYSIS != "all" ) && ( $RUN == "all" ) ]]; then
    echo "sorry , can't run specific analysis on all runs - please specify a run name for this"
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
    echo "analysis requested : $ANALYSIS"
    echo "dry run : $DRY_RUN"
    echo "interactive : $INTERACTIVE"
    echo "machine : $MACHINE"
}

function load_modules() {
    module load bcl2fastq
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

get_opts $@

check_opts

echo_opts

load_modules

# from here , in line code to do the processing
RUN_ROOT=${BUILD_ROOT}/${RUN}.processed_in_progress
BCL2FASTQ_FOLDER=${RUN_ROOT}/bcl2fastq
PARAMETERS_FILE=$BUILD_ROOT/${RUN}.SampleProcessing.json

if [ $RUN == "all"  ]; then 
   echo " are you sure you want to check all runs ? (y/n)"
   read response
   if [ "$response" != "y" ]; then
      echo "OK - to process a single run, enter (e.g.)
      ./process_hiseq1.0.sh -r 150326_D00390_0220_BC6GKKANXX
      "
      echo "quitting"
      exit 1
   fi
   completed_run_landmarks=$HISEQ_ROOT/*/RTAComplete.txt
else
   completed_run_landmarks=$HISEQ_ROOT/$RUN/RTAComplete.txt
fi

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

   if [ $ANALYSIS != "all" ]; then

      if [ $ANALYSIS == "mapping" ]; then
         set -x
         rm -Ir $MAPPING_FOLDER
         MAKE_TARGET="processed_in_progress/mapping_preview"
      elif [ $ANALYSIS == "contamination" ]; then
         set -x
         MAKE_TARGET="processed_in_progress/taxonomy_analysis"
      elif [ $ANALYSIS == "bcl2fastq" ]; then
         set -x
         MAKE_TARGET="processed_in_progress/bcl2fastq"
      else
         echo "Invalid analysis name - must be mapping , contamination , bcl2fastq or all " >&2
         exit 1
      fi
      set +x
   fi

   if [ $DRY_RUN == "yes" ]; then
      echo "****** DRY RUN ONLY ******"
      set -x
      make -n -d -f process_hiseq1.0.mk -j 24 --no-builtin-rules run=${RUN} machine=${MACHINE} hiseq_root=$HISEQ_ROOT $BUILD_ROOT/${run}.${MAKE_TARGET} > $BUILD_ROOT/${run}.log 2>&1
   else
      set -x
      make -d -f process_hiseq1.0.mk -j 24 --no-builtin-rules run=${RUN} machine=${MACHINE} hiseq_root=$HISEQ_ROOT $BUILD_ROOT/${run}.${MAKE_TARGET} > $BUILD_ROOT/${run}.log 2>&1
      echo ""
   fi

   # make a precis of the log file for easier reading
   make -f process_hiseq1.0.mk -i --no-builtin-rules $BUILD_ROOT/${run}.logprecis > /dev/null 2>&1

   # make a summary of the versions of software that were run
   #make -f process_hiseq1.0.mk -i --no-builtin-rules versions.log 

   set +x
done

exit
