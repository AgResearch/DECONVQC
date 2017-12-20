#!/bin/sh

if [ -z "$1" ]; then
   echo "usage :
      ./run_kmer_analysis.sh run_name  working folder
      e.g.
      ./run_kmer_analysis.sh 170511_D00390_0302_BCA92MANXX /bifo/scratch/hiseq/postprocessing/170511_D00390_0302_BCA92MANXX.processed/kmer_analysis
      "
   exit 1
fi

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
HPC_RESOURCE=condor

if [ ! -d ${WORKING_FOLDER} ]; then
   echo "error ${WORKING_FOLDER} is missing"
   exit 1
fi

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

# for each sample , the taxonomy analysis folder contains files Sample_[sample_name].list.sample.fastq.trimmed.gz 
# these are what we need for the kmer analysis   
# (go back to the original bclfastq results to get the sample names)
set -x
files_to_analyse=""
for sample_trimmed_file in $TAX_FOLDER/*.fastq.trimmed.gz; do
   sample_name=`basename $sample_trimmed_file .list.sample.fastq.trimmed.gz`
   downstream_processing=`$GBS_BIN/get_processing_parameters.py --parameter_file ${PARAMETERS_FILE} --parameter_name downstream_processing --sample $sample_name`
   echo $downstream_processing | grep -iq gbs
   if [ $? == 0 ]; then
      files_to_analyse="$files_to_analyse $sample_trimmed_file"
   fi
done

# do kmer analysis on the required files 
if [ $DRY_RUN != "no" ]; then 
   echo "
kmer_entropy.py -t zipfian -k 6 -p 20 -b ${WORKING_FOLDER} -o ${WORKING_FOLDER}/kmer_summary.txt $files_to_analyse
/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla  $GBS_BIN/kmer_plots_gbs.r datafolder=${WORKING_FOLDER} 1>${WORKING_FOLDER}/plots.stdout 2>${WORKING_FOLDER}/plots.stderr
   "
else
   kmer_entropy.py -t zipfian -k 6 -p 20 -b ${WORKING_FOLDER} -o ${WORKING_FOLDER}/kmer_summary.txt $files_to_analyse
   /dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla  $GBS_BIN/kmer_plots_gbs.r datafolder=${WORKING_FOLDER} 1>${WORKING_FOLDER}/plots.stdout 2>${WORKING_FOLDER}/plots.stderr
fi
set +x

echo "*** run_kmer_analysis.sh has completed ***"

exit 0
