#!/bin/sh

# this script is called by the pipeline to merge the uneak results 
# from one or more enzymes into the main uneak folder. It is called like this from the pipeline: 
#
#merge_enzymes.sh %.sample_in_progress/uneak_in_progress %.sample_in_progress/uneak_in_progress/PstI.enzyme %.sample_in_progress/uneak_in_progress/PstI-MspI.enzyme  etc
# (i.e. the merge folder is mentioned first, then one or more enzyme folders) 
#
# or could be called like this on a completed run 
#merge_enzymes.sh /dataset/hiseq/scratch/postprocessing/170413_D00390_0295_BCA5EWANXX.gbs/SQ0419.processed_sample/uneak /dataset/hiseq/scratch/postprocessing/170413_D00390_0295_BCA5EWANXX.gbs/SQ0419.processed_sample/uneak/PstI.enzyme /dataset/hiseq/scratch/postprocessing/170413_D00390_0295_BCA5EWANXX.gbs/SQ0419.processed_sample/uneak/PstI-MspI.enzyme

merge_folder=$1
shift 

# handle the (most common) case of just a single enzyme
if [ -z "$2" ]; then
   echo "linking $1 into $merge_folder"
   enzyme_folder=$1
   for file_or_folder in $enzyme_folder/*; do
      base=`basename $file_or_folder`
      ln -s $file_or_folder $merge_folder/$base
   done
else
   # some initial clean-ups in case we are running this multiple times 
   rm -f $merge_folder/TagCount.csv
   rm -f $merge_folder/SampleStats.csv
   rm -f $merge_folder/kgd.stdout
   while [ ! -z "$1" ]; do
      echo "merging $1 into $merge_folder"
      enzyme_folder=$1
      enzyme_moniker=`basename $enzyme_folder`
      enzyme_moniker=`echo $enzyme_moniker | awk -F. '{print $1}' -`

      # 1 : handle files in the enzyme folder - some are linked (stdout, stderr) , some are concatenated  (TagCounts)
      # create merged tag count stats 
      cat $enzyme_folder/TagCount.csv >> $merge_folder/TagCount.csv

      # link stdout and stderr files 
      for suffix in .out .se ; do
         for filename in $enzyme_folder/*${suffix} ; do
            base=`basename $filename $suffix`
            ln -s $filename $merge_folder/${base}_${enzyme_moniker}${suffix}
         done
      done


      # 2 : handle folders in the enzyme folder - some are linked (hapMap, mapInfo etc) , some are merged (tagCounts, KGD)
      # create merged tagCounts folder
      mkdir -p $merge_folder/tagCounts
      for filename in $enzyme_folder/tagCounts/* ; do
         base=`basename $filename`
         cp -s $filename $merge_folder/tagCounts/$base
      done 

      # create merged KGD. SampleStats.csv  and stdout is merged , and also each component is linked. All other 
      # files are just linked 
      mkdir -p $merge_folder/KGD
      for suffix in .png .csv .pdf .stdout ; do
         for filename in $enzyme_folder/KGD/*${suffix} ; do
            base=`basename $filename $suffix`
            ln -s $filename $merge_folder/KGD/${base}_${enzyme_moniker}${suffix}
         done
      done
      set -x
      cat $enzyme_folder/KGD/SampleStats.csv >>  $merge_folder/KGD/SampleStats.csv
      echo "**** $enzyme_moniker ****" >> $merge_folder/KGD/kgd.stdout
      cat $enzyme_folder/KGD/kgd.stdout >> $merge_folder/KGD/kgd.stdout
      set +x


      # link hapMap tagsByTaxa Illumina  mapInfo key mergedTagCounts  tagPair 
      for subfolder in hapMap tagsByTaxa Illumina  mapInfo key mergedTagCounts  tagPair ; do
         ln -s $enzyme_folder/$subfolder $merge_folder/${subfolder}_${enzyme_moniker}
      done
      
      shift
   done
fi
