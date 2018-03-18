#!/bin/sh
#
# this does generic Q/C on the hiseq output.
# it is run after process_hiseq.sh , and usually concurrently with gbs_hiseq.sh
# 
# examples : 
# ./qc_hiseq1.0.sh -n -r 150515_D00390_0227_BC6JPMANXX
# ./qc_hiseq1.0.sh -n -a mapping -r 150515_D00390_0227_BC6JPMANXX
# ./qc_hiseq1.0.sh -r 150515_D00390_0227_BC6JPMANXX
# ./qc_hiseq1.0.sh -a contamination -r 150515_D00390_0227_BC6JPMANXX

function get_opts() {

help_text="
 examples : \n
 ./qc_hiseq1.0.sh -i -n -r 150515_D00390_0227_BC6JPMANXX \n
 ./qc_hiseq1.0.sh -i -n -a mapping -r 150515_D00390_0227_BC6JPMANXX \n
 ./qc_hiseq1.0.sh -i -r 150515_D00390_0227_BC6JPMANXX \n
 ./qc_hiseq1.0.sh -i -a contamination -r 150515_D00390_0227_BC6JPMANXX \n
 ./qc_hiseq1.0.sh -i -t annotation -r 150515_D00390_0227_BC6JPMANXX \n
"

DRY_RUN=no
INTERACTIVE=no
ANALYSIS=all
RUN=all
MACHINE=hiseq
TASK=all

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
    t)
      TASK=$OPTARG
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

CANONICAL_HISEQ_ROOT=/dataset/hiseq/active
CANONICAL_BUILD_ROOT=/dataset/hiseq/scratch/postprocessing

}


function check_opts() {
# check args
if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi

if [[ ( $ANALYSIS != "all" ) && ( $ANALYSIS != "mapping" ) && ( $ANALYSIS != "contamination" )  ]]; then
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

# task must be all or annotation 
if [[ ( $TASK != "all" ) && ( $TASK != "annotation" ) ]]; then
    echo "task must be all or annotation"
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

get_opts $@

check_opts

echo_opts

# from here , in line code to do the processing
RUN_ROOT=${BUILD_ROOT}/${RUN}.processed
BCL2FASTQ_FOLDER=${RUN_ROOT}/bcl2fastq
PARAMETERS_FILE=$BUILD_ROOT/${RUN}.SampleProcessing.json

if [ $RUN == "all"  ]; then 
   echo " are you sure you want to check all runs ? (y/n)"
   read response
   if [ "$response" != "y" ]; then
      echo "OK - to process a single run, enter (e.g.)
      ./qc_hiseq1.0.sh -r 150326_D00390_0220_BC6GKKANXX
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
   echo "(logging to  $BUILD_ROOT/${run}.gc.log)"

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

   RUN_ROOT=${BUILD_ROOT}/${run}.processed
   MAPPING_FOLDER=${RUN_ROOT}/mapping_analysis_in_progress

   # get the parameters that cnotrol the Q/C run - e.g.
   # reference genomes , blast database to use etc
   get_parameters

   MAKE_TARGET="all"

   if [ $ANALYSIS != "all" ]; then

      if [ $ANALYSIS == "mapping" ]; then
         set -x
         rm -Ir $MAPPING_FOLDER
         MAKE_TARGET="processed/mapping_preview"
      elif [ $ANALYSIS == "contamination" ]; then
         set -x
         MAKE_TARGET="processed/taxonomy_analysis"
      else
         echo "Invalid analysis name - must be mapping , contamination , bcl2fastq or all " >&2
         exit 1
      fi
      set +x
   fi


   function post_make() {

      if [ $DRY_RUN == "yes" ]; then
         echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql"
         echo $GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
         echo "/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla $GBS_BIN/taxonomy_clustering.r run_name=$RUN"
         echo "convert $BUILD_ROOT/euk_taxonomy_clustering_${RUN}.jpg $BUILD_ROOT/all_taxonomy_clustering_${RUN}.jpg $BUILD_ROOT/xno_taxonomy_clustering_${RUN}.jpg  -append $BUILD_ROOT/taxonomy_clustering_${RUN}.jpg"
         echo "
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_F.jpg > $BUILD_ROOT/taxonomy_heatmap_F_90.jpg  
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_R.jpg > $BUILD_ROOT/taxonomy_heatmap_R_90.jpg  
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_M.jpg > $BUILD_ROOT/taxonomy_heatmap_M_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_T.jpg > $BUILD_ROOT/taxonomy_heatmap_T_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_D.jpg > $BUILD_ROOT/taxonomy_heatmap_D_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_A.jpg > $BUILD_ROOT/taxonomy_heatmap_A_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_G.jpg > $BUILD_ROOT/taxonomy_heatmap_G_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_C.jpg > $BUILD_ROOT/taxonomy_heatmap_C_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_S.jpg > $BUILD_ROOT/taxonomy_heatmap_S_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_P.jpg > $BUILD_ROOT/taxonomy_heatmap_P_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_W.jpg > $BUILD_ROOT/taxonomy_heatmap_W_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_misc.jpg > $BUILD_ROOT/taxonomy_heatmap_misc_90.jpg    
         "
         echo "convert $BUILD_ROOT/taxonomy_heatmap_F_90.jpg  $BUILD_ROOT/taxonomy_heatmap_R_90.jpg $BUILD_ROOT/taxonomy_heatmap_M_90.jpg $BUILD_ROOT/taxonomy_heatmap_T_90.jpg $BUILD_ROOT/taxonomy_heatmap_D_90.jpg $BUILD_ROOT/taxonomy_heatmap_A_90.jpg $BUILD_ROOT/taxonomy_heatmap_G_90.jpg  $BUILD_ROOT/taxonomy_heatmap_C_90.jpg  $BUILD_ROOT/taxonomy_heatmap_S_90.jpg  $BUILD_ROOT/taxonomy_heatmap_P_90.jpg  $BUILD_ROOT/taxonomy_heatmap_W_90.jpg $BUILD_ROOT/taxonomy_heatmap_misc_90.jpg -append $BUILD_ROOT/taxonomy_heatmaps.jpg"
         echo "psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql"
         echo "$GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt"
         echo "$GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt"
      else
         psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_sample_species.psql
         $GBS_BIN/summarise_global_hiseq_taxonomy.sh $RUN
         /dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla $GBS_BIN/taxonomy_clustering.r run_name=$RUN
         convert $BUILD_ROOT/euk_taxonomy_clustering_${RUN}.jpg $BUILD_ROOT/all_taxonomy_clustering_${RUN}.jpg $BUILD_ROOT/xno_taxonomy_clustering_${RUN}.jpg  -append $BUILD_ROOT/taxonomy_clustering_${RUN}.jpg
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_F.jpg > $BUILD_ROOT/taxonomy_heatmap_F_90.jpg  
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_R.jpg > $BUILD_ROOT/taxonomy_heatmap_R_90.jpg  
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_M.jpg > $BUILD_ROOT/taxonomy_heatmap_M_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_T.jpg > $BUILD_ROOT/taxonomy_heatmap_T_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_D.jpg > $BUILD_ROOT/taxonomy_heatmap_D_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_A.jpg > $BUILD_ROOT/taxonomy_heatmap_A_90.jpg   
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_G.jpg > $BUILD_ROOT/taxonomy_heatmap_G_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_C.jpg > $BUILD_ROOT/taxonomy_heatmap_C_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_S.jpg > $BUILD_ROOT/taxonomy_heatmap_S_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_P.jpg > $BUILD_ROOT/taxonomy_heatmap_P_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_W.jpg > $BUILD_ROOT/taxonomy_heatmap_W_90.jpg    
         jpegtran -rotate 90 $BUILD_ROOT/taxonomy_heatmap_misc.jpg > $BUILD_ROOT/taxonomy_heatmap_misc_90.jpg    

         convert $BUILD_ROOT/taxonomy_heatmap_F_90.jpg  $BUILD_ROOT/taxonomy_heatmap_R_90.jpg $BUILD_ROOT/taxonomy_heatmap_M_90.jpg $BUILD_ROOT/taxonomy_heatmap_T_90.jpg $BUILD_ROOT/taxonomy_heatmap_D_90.jpg $BUILD_ROOT/taxonomy_heatmap_A_90.jpg $BUILD_ROOT/taxonomy_heatmap_G_90.jpg  $BUILD_ROOT/taxonomy_heatmap_C_90.jpg  $BUILD_ROOT/taxonomy_heatmap_S_90.jpg  $BUILD_ROOT/taxonomy_heatmap_P_90.jpg  $BUILD_ROOT/taxonomy_heatmap_W_90.jpg $BUILD_ROOT/taxonomy_heatmap_misc_90.jpg -append $BUILD_ROOT/taxonomy_heatmaps.jpg
         psql -U agrbrdf -d agrbrdf -h invincible -f $GBS_BIN/database/extract_peacock.psql
         $GBS_BIN/database/make_peacock_plots.sh $BUILD_ROOT/peacock_data.txt
         $GBS_BIN/database/make_run_plots.py -r $RUN -o $BUILD_ROOT/${RUN}_plots.html $BUILD_ROOT/peacock_data.txt
      fi
   }

   if [ $DRY_RUN == "yes" ]; then
      echo "****** DRY RUN ONLY ******"
      if [ $TASK == "all" ]; then 
         make -n -d -k -f qc_hiseq1.0.mk -j 24 --no-builtin-rules run=${RUN} machine=${MACHINE} hiseq_root=$HISEQ_ROOT $BUILD_ROOT/${run}.${MAKE_TARGET} > $BUILD_ROOT/${run}.qc.log 2>&1
      fi
      post_make
   else
      set -x
      if [ $TASK == "all" ] ; then
         make -d -k -f qc_hiseq1.0.mk -j 24 --no-builtin-rules run=${RUN} machine=${MACHINE} hiseq_root=$HISEQ_ROOT $BUILD_ROOT/${run}.${MAKE_TARGET} > $BUILD_ROOT/${run}.qc.log 2>&1
         if [ $? == 0 ]; then
            post_make
         else
            echo "(non-zero exit status from make - skipping post_make)"
            exit 1
         fi
      else
         post_make
      fi
   fi

   # make a precis of the log file for easier reading
   make -k -f qc_hiseq1.0.mk -i --no-builtin-rules $BUILD_ROOT/${run}.qc.logprecis > /dev/null 2>&1

   # make a summary of the versions of software that were run
   #make -f qc_hiseq1.0.mk -i --no-builtin-rules versions.log 

   set +x
done

exit
