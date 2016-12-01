#!/bin/sh

if [ -z "$1" ]; then
   echo "usage :
      ./run_mapping_preview.sh run_name  machine
      e.g.
      ./run_mapping_preview.sh 141217_D00390_0214_BC4UEHACXX hiseq
      "
   exit 1
fi

module load samtools

RUN=$1
MACHINE=$2
HPC_RESOURCE=local

HISEQ_ROOT=/dataset/${MACHINE}/active
BUILD_ROOT=/dataset/${MACHINE}/scratch/postprocessing
RUN_ROOT=${BUILD_ROOT}/${RUN}.processed_in_progress
PARAMETERS_FILE=$BUILD_ROOT/${RUN}.SampleProcessing.json
WORKING_FOLDER=${RUN_ROOT}/mapping_preview_in_progress
TAX_FOLDER=${RUN_ROOT}/taxonomy_analysis
BCL2FASTQ_FOLDER=${RUN_ROOT}/bcl2fastq

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

cd $GBS_BIN
if [ ! -f .tardishrc ]; then 
   echo "error - tardis config file .tardishrc is missing. "
   exit 1
fi


# for each sample , the taxonomy analysis folder contains files Sample_[sample_name].list.sample.fastq.trimmed.gz 
# these are what we need for the mapping preview  
# (go back to the original bclfastq results to get the sample names)
for sample_trimmed_file in $TAX_FOLDER/*.fastq.trimmed.gz; do
   sample_name=`basename $sample_trimmed_file .list.sample.fastq.trimmed.gz`
   batonfile=${WORKING_FOLDER}/${sample_name}.bwa.baton
   if [ ! -d $WORKING_FOLDER/$sample_name ]; then
       mkdir $WORKING_FOLDER/$sample_name 
   fi
   REF_GENOME=`$GBS_BIN/get_processing_parameters.py --parameter_file ${PARAMETERS_FILE} --parameter_name bwa_alignment_reference  --sample $sample_name`
   alignment_parameters=`$GBS_BIN/get_processing_parameters.py --parameter_file ${PARAMETERS_FILE} --parameter_name bwa_alignment_parameters`
   sample_trimmed_moniker=${sample_name}.sample.fastq.trimmed
   if [ ! -z $REF_GENOME ]; then
      if [ ! -f ${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.bam ]; then 
         echo "queuing $sample_trimmed_file"
         REF_GENOME_MONIKER=`basename $REF_GENOME`
         nohup tardis.py -w -k -c 200 -hpctype $HPC_RESOURCE -d $WORKING_FOLDER/$sample_name -batonfile $batonfile bwa aln $alignment_parameters $REF_GENOME _condition_fastq_input_$sample_trimmed_file \> _condition_throughput_${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.sai \; bwa samse $REF_GENOME _condition_throughput_${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}.sai _condition_fastq_input_$sample_trimmed_file  \> _condition_sam_output_$WORKING_FOLDER/${sample_trimmed_moniker}_vs_${REF_GENOME_MONIKER}  &
      fi
   else
      echo "skipping $sample_name (no reference specified)"
   fi
done

# wait for and summarise each output file 
for sample_trimmed_file in $TAX_FOLDER/*.fastq.trimmed.gz; do
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

# do a grand summary  ?

echo "*** run_mapping_preview.sh has completed ***"

exit 0
