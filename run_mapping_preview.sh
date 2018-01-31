#!/bin/sh

if [ -z "$1" ]; then
   echo "usage :
      ./run_mapping_preview.sh run_name  working folder
      e.g.
      ./run_mapping_preview.sh 161219_D00390_0277_BC9P3HANXX /bifo/scratch/hiseq/postprocessing/161219_D00390_0277_BC9P3HANXX.processed/mapping_preview
      "
   exit 1
fi

#module load samtools
module load samtools14_env 

RUN=$1
WORKING_FOLDER=$2
DRY_RUN=$3

if [ -z "$DRY_RUN" ]; then
   DRY_RUN="no"
elif [[ $DRY_RUN == "y" || $DRY_RUN == "Y" || $DRY_RUN == "yes" ]]; then
   DRY_RUN="yes"
else
   DRY_RUN="no"
fi

BCL2FASTQ_FOLDER=${WORKING_FOLDER}/../bcl2fastq/
TAX_FOLDER=${WORKING_FOLDER}/../taxonomy_analysis
PARAMETERS_FILE=${WORKING_FOLDER}/../../${RUN}.SampleProcessing.json
RUN_ROOT=${WORKING_FOLDER}/..

if [ -z "$HPC_RESOURCE" ]; then
   HPC_RESOURCE=local
fi

echo "HPC_RESOURCE=$HPC_RESOURCE"


BATCHSIZE=4

if [ ! -f $PARAMETERS_FILE ]; then
   echo "$PARAMETERS_FILE missing - please run get_processing_parameters.py (for help , ./get_processing_parameters.py -h)"
   exit 1
fi
if [ ! -d ${BCL2FASTQ_FOLDER} ]; then
   echo "error ${BCL2FASTQ_FOLDER} is missing"
   exit 1
fi
if [ ! -d ${TAX_FOLDER} ]; then
   echo "error ${TAX_FOLDER} is missing"
   exit 1
fi
if [ ! -d ${WORKING_FOLDER} ]; then
   echo "error ${WORKING_FOLDER} is missing"
   exit 1
fi

#cd $GBS_BIN
#if [ ! -f .tardishrc ]; then 
#   echo "error - tardis config file .tardishrc is missing. "
#   exit 1
#fi
cd $WORKING_FOLDER
echo """
[tardis_engine]
max_processes=5
""" > .tardishrc


function get_files_by_size() {
# for each sample , the taxonomy analysis folder contains files Sample_[sample_name].list.sample.fastq.trimmed.gz 
# these are what we need for the mapping preview  
   lof=$1
   tmpfile=`mktemp`
   for sample_trimmed_file in $TAX_FOLDER/*.fastq.trimmed.gz; do
      # get the (real) size of the file
      byte_count=`du -bL $sample_trimmed_file | awk '{print $1}' -`
      echo "$byte_count $sample_trimmed_file" | awk '{printf("%015d,%s\n", $1, $2);}' - >> $tmpfile
   done
   sort -r $tmpfile > ${tmpfile}.srt
   awk -F, '{print $2}' ${tmpfile}.srt > $lof
}


# make a list of list files sorted by filesize (biggest first) so we can prioritise
get_files_by_size ${RUN_ROOT}/lof.txt

# now loop through launching BATCHSIZE at a time
# (go back to the original bclfastq results to get the sample names)

sample_count=`wc ${RUN_ROOT}/lof.txt | awk '{print $1}' -`
launched_count=0
launched_list=`mktemp`
set -x
for sample_trimmed_file in `cat ${RUN_ROOT}/lof.txt`; do
   sample_name=`basename $sample_trimmed_file .list.sample.fastq.trimmed.gz`
   batonfile=${WORKING_FOLDER}/${sample_name}.bwa.baton
   if [ ! -d $WORKING_FOLDER/$sample_name ]; then
       mkdir $WORKING_FOLDER/$sample_name 
   fi
   REF_GENOME=`$GBS_BIN/get_processing_parameters.py --parameter_file ${PARAMETERS_FILE} --parameter_name bwa_alignment_reference  --sample $sample_name`
   alignment_parameters=`$GBS_BIN/get_processing_parameters.py --parameter_file ${PARAMETERS_FILE} --parameter_name bwa_alignment_parameters`
   sample_trimmed_moniker=${sample_name}.sample.fastq.trimmed
   if [ ! -f ${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.bam ]; then 
      echo "queuing $sample_trimmed_file"
      REF_GENOME_MONIKER=`basename $REF_GENOME`
      if [ $DRY_RUN == "yes" ]; then
         echo "*** dry run only ***"
         if [ ! -z $REF_GENOME ]; then 
            echo "nohup tardis.py -w -k -c 200 -hpctype $HPC_RESOURCE -d $WORKING_FOLDER/$sample_name -batonfile $batonfile bwa aln $alignment_parameters $REF_GENOME _condition_fastq_input_$sample_trimmed_file \> _condition_throughput_${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.sai \; bwa samse $REF_GENOME _condition_throughput_${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.sai _condition_fastq_input_$sample_trimmed_file  \> _condition_sam_output_$WORKING_FOLDER/${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.bam  & "
         fi
      else 
         if [ ! -z $REF_GENOME ]; then
            nohup tardis.py -w -k -c 200 -hpctype $HPC_RESOURCE -d $WORKING_FOLDER/$sample_name -batonfile $batonfile bwa aln $alignment_parameters $REF_GENOME _condition_fastq_input_$sample_trimmed_file \> _condition_throughput_${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.sai \; bwa samse $REF_GENOME _condition_throughput_${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.sai _condition_fastq_input_$sample_trimmed_file  \> _condition_sam_output_$WORKING_FOLDER/${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.bam  & 
         fi
         let launched_count=$launched_count+1
         echo $sample_trimmed_file >> $launched_list

         # if we have launched BATCHSIZE, or all of them, wait for this batch to complete
         let modcount=${launched_count}%$BATCHSIZE
         if [[ (  $modcount == 0 ) || (  ${launched_count} == $sample_count ) ]]; then
            for sample_trimmed_file in `cat $launched_list`; do
               sample_name=`basename $sample_trimmed_file .list.sample.fastq.trimmed.gz`
               batonfile=${WORKING_FOLDER}/${sample_name}.bwa.baton
               sample_trimmed_moniker=${sample_name}.sample.fastq.trimmed
               REF_GENOME=`$GBS_BIN/get_processing_parameters.py --parameter_file ${PARAMETERS_FILE} --parameter_name bwa_alignment_reference  --sample $sample_name`
               if [ ! -z $REF_GENOME ]; then
                  REF_GENOME_MONIKER=`basename $REF_GENOME`
                  echo "waiting for $batonfile"
                  while [ ! -f $batonfile ]; do  
                     sleep 180 
                  done
               fi
               # summarise the alignment  
               rm -f $batonfile
               if [ -f $WORKING_FOLDER/${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.bam ]; then
                  bamtools stats -in $WORKING_FOLDER/${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.bam > $WORKING_FOLDER/${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.stats
               fi
            done
            launched_list=`mktemp`
         fi
      fi
   fi
done


# do a grand summary  
$GBS_BIN/summarise_bwa_mappings.sh $RUN $WORKING_FOLDER

set +x 

echo "*** run_mapping_preview.sh has completed ***"

exit 0
