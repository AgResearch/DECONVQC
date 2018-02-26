#!/bin/sh
# this script is used to merge the uneak results 
# from one or more cohorts into the main uneak folder.
# 
# examples : 
# ./merge_cohorts.sh -n -r 170421_D00390_0296_ACA647ANXX
# ./merge_cohorts.sh -r 170421_D00390_0296_ACA647ANXX

function get_opts() {

help_text="
 examples : \n
 ./merge_cohorts.sh -n -r 170421_D00390_0296_ACA647ANXX \n
 ./merge_cohorts.sh -r 170421_D00390_0296_ACA647ANXX \n
"

DRY_RUN=no
MACHINE=hiseq

while getopts ":nhr:m:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    r)
      RUN=$OPTARG
      ;;
    m)
      MACHINE=$OPTARG
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

if [ -z "$RUN" ]; then 
   echo "must specify a run (-r RUN )"
   exit 1
fi

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

# check results folder exists  
if [ ! -d $BUILD_ROOT/${RUN}.gbs ]; then
    echo "could not find $BUILD_ROOT/${RUN}.gbs"
    exit 1
fi

}


function echo_opts() {
    echo "run to merge : $RUN"
}

function safe_link() {
   # since this script is called after (re)running any or all lanes, 
   # then when called after a lane has been re-run , the code can get confused and
   # circular links created. 
   # this function checks for and does not create circular links
   real=$1
   link=$2
   p=`dirname $link` 
   r=`readlink $link`
   if [ "$p" == "$r" ]; then
      echo "ignoring request to ln -s $real $link as this is circular"
   else
      ln -s $real $link 
   fi
}


function merge_cohorts() {
   # this function  is called  to merge the uneak results 
   # from one or more cohorts into the main uneak folder. It is called like this: 
   #
   #merge_cohorts(
   #    /dataset/hiseq/scratch/postprocessing/170413_D00390_0295_BCA5EWANXX.gbs/SQ0419.processed_sample/uneak 
   #     /dataset/hiseq/scratch/postprocessing/170413_D00390_0295_BCA5EWANXX.gbs/SQ0419.processed_sample/uneak/PstI.cohort 
   #     /dataset/hiseq/scratch/postprocessing/170413_D00390_0295_BCA5EWANXX.gbs/SQ0419.processed_sample/uneak/PstI-MspI.cohort
   # - i.e. merge folder first


   merge_folder=$1
   shift 

   # handle the (most common) case of just a single cohort
   if [ -z "$2" ]; then
      echo "linking $1 into $merge_folder"
      cohort_folder=$1
      for file_or_folder in $cohort_folder/*; do
         base=`basename $file_or_folder`
         safe_link $file_or_folder $merge_folder/$base
      done
   else
      # some initial clean-ups in case we are running this multiple times 
      rm -f $merge_folder/TagCount.csv
      rm -f $merge_folder/SampleStats.csv
      rm -f $merge_folder/kgd.stdout
      while [ ! -z "$1" ]; do
         echo "merging $1 into $merge_folder"
         cohort_folder=$1
         cohort_moniker=`basename $cohort_folder`
         cohort_moniker=`echo $cohort_moniker | awk -F. '{print $1}' -`

         # 1 : handle files in the cohort folder - some are linked (stdout, stderr) , some are concatenated  (TagCounts)
         # create merged tag count stats 
         cat $cohort_folder/TagCount.csv >> $merge_folder/TagCount.csv

         # link stdout and stderr files 
         for suffix in .out .se ; do
            for filename in $cohort_folder/*${suffix} ; do
               base=`basename $filename $suffix`
               safe_link $filename $merge_folder/${base}_${cohort_moniker}${suffix}
            done
         done


         # 2 : handle folders in the cohort folder - some are linked (hapMap, mapInfo etc) , some are merged (tagCounts, KGD)
         # create merged tagCounts folder
         mkdir -p $merge_folder/tagCounts
         for filename in $cohort_folder/tagCounts/* ; do
            base=`basename $filename`
            cp -s $filename $merge_folder/tagCounts/$base
         done 
   
         # create merged KGD. SampleStats.csv  and stdout is merged , and also each component is linked. All other 
         # files are just linked 
         mkdir -p $merge_folder/KGD
         for suffix in .png .csv .pdf .stdout ; do
            for filename in $cohort_folder/KGD/*${suffix} ; do
               base=`basename $filename $suffix`
               safe_link $filename $merge_folder/KGD/${base}_${cohort_moniker}${suffix}
            done
         done
         set -x
         cat $cohort_folder/KGD/SampleStats.csv >>  $merge_folder/KGD/SampleStats.csv
         echo "**** $cohort_moniker ****" >> $merge_folder/KGD/kgd.stdout
         cat $cohort_folder/KGD/kgd.stdout >> $merge_folder/KGD/kgd.stdout
         set +x


         # link hapMap tagsByTaxa Illumina  mapInfo key mergedTagCounts  tagPair 
         for subfolder in hapMap tagsByTaxa Illumina  mapInfo key mergedTagCounts  tagPair ; do
            safe_link $cohort_folder/$subfolder $merge_folder/${subfolder}_${cohort_moniker}
         done
      
         shift
      done
   fi
}

get_opts $@
check_opts
echo_opts

if [ $DRY_RUN == "yes" ]; then
   echo "will merge as follows : "
   for processed_sample_uneak in $BUILD_ROOT/${RUN}.gbs/*.processed_sample/uneak; do 
      cohort_folders=${processed_sample_uneak}/*.cohort
      echo merge_cohorts $processed_sample_uneak $cohort_folders   
   done 
   echo "*** DRY RUN ONLY ***"
else
   set -x
   for processed_sample_uneak in $BUILD_ROOT/${RUN}.gbs/*.processed_sample/uneak; do 
      cohort_folders=${processed_sample_uneak}/*.cohort
      merge_cohorts $processed_sample_uneak $cohort_folders 
   done 
   set +x 
fi





