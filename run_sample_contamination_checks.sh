#!/bin/sh

if [ -z "$3" ]; then
   echo "usage :
      ./run_sample_contamination_checks.sh run working_folder tardis_chunksize  sample_rate 
      or
      ./run_sample_contamination_checks.sh run working_folder tardis_chunksize  sample_rate blast-only # if sampling and trimming already done and just want to run blast
      or 
      ./run_sample_contamination_checks.sh run working_folder tardis_chunksize  sample_rate trim-only # if just want to sample and trim
      e.g.
      ./run_sample_contamination_checks.sh 161118_D00390_0273_BC9NB4ANXX /dataset/hiseq/scratch/postprocessing/161118_D00390_0273_BC9NB4ANXX.processed/taxonomy_analysis 400000 .00005
      "
   exit 1
fi

#
# refseq_genomic database is from wget --no-verbose --timestamping ftp://ftp.wip.ncbi.nlm.nih.gov/blast/db/refseq_genomic.*
#

RUN=$1
WORKING_FOLDER=$2
TARDIS_chunksize=$3
SAMPLE_RATE=$4
SELECT=$5

BCL2FASTQ_FOLDER=${WORKING_FOLDER}/../bcl2fastq/
PARAMETERS_FILE=${WORKING_FOLDER}/../../${RUN}.SampleProcessing.json
RUN_ROOT=${WORKING_FOLDER}/..


if [ ! -d ${WORKING_FOLDER} ]; then
   echo "error ${WORKING_FOLDER} is missing"
   exit 1
fi

cd $GBS_BIN
if [ ! -f .tardishrc ]; then 
   echo "
[tardish]
Rport=5555
Rhost=localhost


[tardis_engine]
workdir_is_rootdir=True
shell_template_name=condor_shell
# this is somewhat low because typiclly make will launch
# several tardis instances, and each process may itself
# multithread (e.g. blastn)
max_processes=5
hpctype=condor
" > .tardishrc
fi

if [ ! -f $PARAMETERS_FILE ]; then
   echo "$PARAMETERS_FILE missing - please run get_processing_parameters.py (for help , ./get_processing_parameters.py -h)"
   exit 1
fi


# get blast and trimming parameters
blast_database=`$GBS_BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name blast_database`
blast_alignment_parameters=`$GBS_BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name blast_alignment_parameters`
blast_task=`$GBS_BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name blast_task`
adapter_to_cut=`$GBS_BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name adapter_to_cut`

if [ "$SELECT" != "blast-only" ]; then 
   # build a listfile containing fastq files, for each sample  
   rm ${RUN_ROOT}/*.list
   found_file=0
   for file in `find ${BCL2FASTQ_FOLDER} -name "*.fastq.gz" -print `; do 
      found_file=1
      sample=`dirname $file`
      sample=`basename $sample`
      base=`basename $file`
      sample_list_file=${RUN_ROOT}/${sample}.list
      echo "adding $file to $sample_list_file"
      echo $file >> $sample_list_file 
   done

   if [ $found_file == 0 ]; then
      echo "error - no fastq files found under ${BCL2FASTQ_FOLDER}"
      exit 1
   fi

   # if necessary launch each sample for trimming
   for sample_list_file in ${RUN_ROOT}/*.list; do
      sample=`basename $sample_list_file`
      sample_name=`basename $sample .list`
      batonfile=${WORKING_FOLDER}/${sample_name}.trimming.baton
      if [ ! -d ${WORKING_FOLDER}/${sample_name}.trimming ]; then
          mkdir ${WORKING_FOLDER}/${sample_name}.trimming
      fi
      sample_trimmed_file=${WORKING_FOLDER}/${sample}.sample.fastq.trimmed
      echo "queuing $sample_list_file"
      if [ ! -z "$adapter_to_cut" ]; then
         nohup tardis.py -w -c ${TARDIS_chunksize} -s ${SAMPLE_RATE} -d ${WORKING_FOLDER}/${sample_name}.trimming -batonfile $batonfile cutadapt -f fastq -a $adapter_to_cut _condition_fastq_input_$sample_list_file  \> _condition_fastq_output_$sample_trimmed_file 2\>_condition_text_output_${WORKING_FOLDER}/${sample}.sample.fastq.trimmed.report &
      else
         nohup tardis.py -w -c ${TARDIS_chunksize} -s ${SAMPLE_RATE} -d ${WORKING_FOLDER}/${sample_name}.trimming -batonfile $batonfile cat  _condition_fastq_input_$sample_list_file  \> _condition_fastq_output_$sample_trimmed_file &
      fi
   done

   # wait for the trimming to complete
   for sample_list_file in ${RUN_ROOT}/*.list; do
      sample=`basename $sample_list_file`
      sample_name=`basename $sample .list`
      batonfile=${WORKING_FOLDER}/${sample_name}.trimming.baton
      echo "waiting for $batonfile "
      while [ ! -f $batonfile ]; do
         sleep 180
      done
      rm $batonfile
   done
else
   echo "(skipping trim)"
fi



# launch each sample for blast
if [ "$SELECT" != "trim-only" ]; then
   echo "starting blasts"
   for sample_list_file in ${RUN_ROOT}/*.list; do
      sample=`basename $sample_list_file`
      sample_name=`basename $sample .list`
      batonfile=${WORKING_FOLDER}/${sample_name}.blast.baton
      if [ ! -d ${WORKING_FOLDER}/${sample_name}.blast ]; then
          mkdir ${WORKING_FOLDER}/${sample_name}.blast
      fi
      sample_trimmed_file=${WORKING_FOLDER}/${sample}.sample.fastq.trimmed.gz
      sample_output_file=${WORKING_FOLDER}/${sample}.blastresults.txt
      echo "queuing $sample_trimmed_file"
      chunk_size=`python -c "print int(${TARDIS_chunksize} * ${SAMPLE_RATE})" `
      nohup tardis.py -w -c $chunk_size -d ${WORKING_FOLDER}/${sample_name}.blast -batonfile $batonfile cat _condition_fastq_input_$sample_trimmed_file \|  /usr/local/agr-scripts/slice_fastq.py -F fasta \| blastn -query - -task $blast_task -num_threads 2 -db $blast_database $blast_alignment_parameters -max_target_seqs 1 -outfmt  \'7 qseqid sseqid pident evalue staxids sscinames scomnames sskingdoms stitle\' -out _condition_text_output_${sample_output_file} 1\>_condition_text_output_${sample_output_file}.stdout 2\>_condition_text_output_${sample_output_file}.stderr > ${sample_output_file}.nohup &
   done


   # wait for the blasts to complete and summarise each file  
   for sample_list_file in ${RUN_ROOT}/*.list; do
      sample=`basename $sample_list_file`
      sample_name=`basename $sample .list`
      batonfile=${WORKING_FOLDER}/${sample_name}.blast.baton
      echo "waiting for $batonfile "
      while [ ! -f $batonfile ]; do  
         sleep 180 
      done
      rm $batonfile
      $GBS_BIN/summarise_hiseq_taxonomy.py  ${WORKING_FOLDER}/${sample}.blastresults.txt.gz 
   done


   # create a table from all summaries - one sample per column, one row per taxon
   $GBS_BIN/summarise_hiseq_taxonomy.py --summary_type summary_table $WORKING_FOLDER/*.pickle > ${WORKING_FOLDER}/samples_taxonomy_table.txt

   # write nt database version info
   blastdbcmd -db $blast_database -info > ${WORKING_FOLDER}/blast_db_info.txt 
else
   echo "(skipping blast)"
fi

echo "*** run_sample_contamination_checks.sh has completed ***"

exit 0
