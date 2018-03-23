#!/bin/bash

if [ -z "$2" ]; then
   echo "usage :
      ./run_sample_contamination_checks.sh run working_folder 
      or
      ./run_sample_contamination_checks.sh run working_folder blast-only # if sampling and trimming already done and just want to run blast
      or 
      ./run_sample_contamination_checks.sh run working_folder trim-only # if just want to sample and trim
      e.g.
      ./run_sample_contamination_checks.sh 161118_D00390_0273_BC9NB4ANXX /dataset/hiseq/scratch/postprocessing/161118_D00390_0273_BC9NB4ANXX.processed/taxonomy_analysis 
      "
   exit 1
fi

#
# refseq_genomic database is from wget --no-verbose --timestamping ftp://ftp.wip.ncbi.nlm.nih.gov/blast/db/refseq_genomic.*
#

set -x

RUN=$1
WORKING_FOLDER=$2

#TARDIS_chunksize=$3  # e.g. 400000 for typical GBS fastq file (10000 for miseq). if 0 then it will be calculated 
#SAMPLE_RATE=$4       # e.g. .00005 for typical GBS fastq file (.002 for miseq) . if 0 then it will be calculated 
#SELECT=$5
SELECT=$3

BCL2FASTQ_FOLDER=${WORKING_FOLDER}/../bcl2fastq/
PARAMETERS_FILE=${WORKING_FOLDER}/../../${RUN}.SampleProcessing.json
RUN_ROOT=${WORKING_FOLDER}/..
BATCHSIZE=4

function get_samplerate_chunksize() {
   # default tardis chunksize method is very slow (it parses the fastq/fasta) so get chunksizes in this script using something a bit faster
   # - if file is very big use filesize as a proxy , with number of seqs ~ .02 * size in bytes of compressed file
   # e.g. 
   # SQ0463_S13_L005_R1_001.fastq.gz , 15,865,094,474 bytes; 302,800,826 reads 
   # cf for example a gtseq file might be around 20,228,653 compressed - if compressed size 100Mbyte or less use 
   # line count 
   filename=$1
   byte_count=`du -bL $filename | awk '{print $1}' -`
   method=`python -c "print {True:'bytes', False:'lines'}[$byte_count > 300000000]"`
   if [ $method == "bytes" ]; then
      read_count=`python -c "print int(.02 * $byte_count)"`
   else 
      line_count=`zcat -f $filename | wc | awk '{print $1}' -`
      read_count=`python -c "print int(1+$line_count/4.0)"`
   fi
   # want sample size of around 15000
   SAMPLE_RATE=`python -c "print '%8.7f'%(min(0.1,15000.0/${read_count}))"`
   # tardis chunks size set to give around 200 jobs or so - note that 
   # this is gross of sampling (tardis calculates actual chunk size)  
   TARDIS_chunksize=`python -c "print max(1, int(${read_count} / 200.0) )"`
}


function get_files_by_size() {
   lolf=$1
   tmpfile=`mktemp`
   for sample_list_file in ${RUN_ROOT}/*.list; do
      # get the real size of the first file in the list
      f=`head -1 $sample_list_file `
      byte_count=`du -bL $f | awk '{print $1}' -`
      echo "$byte_count $sample_list_file" | awk '{printf("%015d,%s\n", $1, $2);}' - >> $tmpfile
   done
   sort -r $tmpfile > ${tmpfile}.srt
   awk -F, '{print $2}' ${tmpfile}.srt > $lolf
}


if [ ! -d ${WORKING_FOLDER} ]; then
   echo "error ${WORKING_FOLDER} is missing"
   exit 1
fi

cd ${WORKING_FOLDER}
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

   # only include GBS samples 
   #for file in `find ${BCL2FASTQ_FOLDER}/*/ -name "*.fastq.gz" -print `; do 
   for folder in ${BCL2FASTQ_FOLDER}/*; do
      if [ ! -d $folder ]; then
         continue
      fi
      sample=`basename $folder`
      downstream=`$GBS_BIN/get_processing_parameters.py --parameter_file $PARAMETERS_FILE --parameter_name downstream_processing --sample $sample`
      if [$downstream == GBS ] ; then
         sample_list_file=${RUN_ROOT}/${sample}.list
         echo "adding files under ${BCL2FASTQ_FOLDER}/$sample to $sample_list_file"
         ls ${BCL2FASTQ_FOLDER}/$sample/*.gz >> $sample_list_file 
      else 
         echo "skipping files under ${BCL2FASTQ_FOLDER}/$sample (downstream is $downstream and we are only processing GBS here)"
      fi 
   done

   # if necessary launch each sample for trimming
   # make a list of list files sorted by filesize (biggest first) so we can prioritise
   get_files_by_size ${RUN_ROOT}/lolf.txt

   # now loop through launching BATCHSIZE at a time
   sample_count=`wc ${RUN_ROOT}/lolf.txt | awk '{print $1}' -`
   launched_count=0
   launched_list=`mktemp`
   set -x
   for sample_list_file in `cat ${RUN_ROOT}/lolf.txt`; do
      sample=`basename $sample_list_file`
      sample_name=`basename $sample .list`
      batonfile=${WORKING_FOLDER}/${sample_name}.trimming.baton
      if [ ! -d ${WORKING_FOLDER}/${sample_name}.trimming ]; then
          mkdir ${WORKING_FOLDER}/${sample_name}.trimming
      fi
      sample_trimmed_file=${WORKING_FOLDER}/${sample}.sample.fastq.trimmed


      if [ -f ${sample_trimmed_file}.gz ]; then
         echo "skipping ${sample_trimmed_file}.gz already done"
         continue
      fi
      #exit  # DEBUG ! - trying to work out why its not skipping 

      echo "queuing $sample_list_file"
      # get sample rate chunksize and method from the first file in the list
      for fastq_file in `cat $sample_list_file` ; do  
         get_samplerate_chunksize $fastq_file
         break
      done
      echo "will use sample rate = ${SAMPLE_RATE}, tardis chunksize = ${TARDIS_chunksize} to trim $sample_list_file"
      if [ ! -z "$adapter_to_cut" ]; then
         nohup tardis.py -w -c ${TARDIS_chunksize} -s ${SAMPLE_RATE} -d ${WORKING_FOLDER}/${sample_name}.trimming -batonfile $batonfile cutadapt -f fastq -a $adapter_to_cut _condition_fastq_input_$sample_list_file  \> _condition_fastq_output_$sample_trimmed_file 2\>_condition_text_output_${WORKING_FOLDER}/${sample}.sample.fastq.trimmed.report &
      else
         nohup tardis.py -w -c ${TARDIS_chunksize} -s ${SAMPLE_RATE} -d ${WORKING_FOLDER}/${sample_name}.trimming -batonfile $batonfile cat  _condition_fastq_input_$sample_list_file  \> _condition_fastq_output_$sample_trimmed_file &
      fi

      let launched_count=$launched_count+1
      echo $sample_list_file >> $launched_list

      # if we have launched BATCHSIZE, or all of them, wait for this batch to complete
      let modcount=${launched_count}%$BATCHSIZE
      if [[ (  $modcount == 0 ) || (  ${launched_count} == $sample_count ) ]]; then
         # wait for the trimming to complete
         for sample_list_file in `cat $launched_list`; do
            sample=`basename $sample_list_file`
            sample_name=`basename $sample .list`
            batonfile=${WORKING_FOLDER}/${sample_name}.trimming.baton
            echo "waiting for $batonfile "
            while [ ! -f $batonfile ]; do
               sleep 180
            done
            rm $batonfile
         done
         launched_list=`mktemp`
      fi
   done 
   set +x
else
   echo "(skipping trim)"
fi



# launch each sample for blast
if [ "$SELECT" != "trim-only" ]; then
   sample_count=`wc ${RUN_ROOT}/lolf.txt | awk '{print $1}' -`
   launched_count=0
   launched_list=`mktemp`
   for sample_list_file in `cat ${RUN_ROOT}/lolf.txt`; do
      sample=`basename $sample_list_file`
      sample_name=`basename $sample .list`
      batonfile=${WORKING_FOLDER}/${sample_name}.blast.baton
      if [ ! -d ${WORKING_FOLDER}/${sample_name}.blast ]; then
          mkdir ${WORKING_FOLDER}/${sample_name}.blast
      fi
      sample_trimmed_file=${WORKING_FOLDER}/${sample}.sample.fastq.trimmed.gz
      sample_output_file=${WORKING_FOLDER}/${sample}.blastresults.txt

      if [ -f ${sample_output_file}.gz ]; then
         echo "skipping ${sample_output_file}.gz already done"
         continue
      fi

      echo "queuing $sample_trimmed_file"
      #chunk_size=`python -c "print int(${TARDIS_chunksize} * ${SAMPLE_RATE})" `
      get_samplerate_chunksize $sample_trimmed_file  # (we only actually want chunk size at this point)
      echo "will use tardis chunksize = ${TARDIS_chunksize} to blast $sample_trimmed_file "
      nohup tardis.py -w -c $TARDIS_chunksize -d ${WORKING_FOLDER}/${sample_name}.blast -batonfile $batonfile cat _condition_fastq_input_$sample_trimmed_file \|  /usr/local/agr-scripts/slice_fastq.py -F fasta \| blastn -query - -task $blast_task -num_threads 2 -db $blast_database $blast_alignment_parameters -max_target_seqs 1 -outfmt  \'7 qseqid sseqid pident evalue staxids sscinames scomnames sskingdoms stitle\' -out _condition_text_output_${sample_output_file} 1\>_condition_text_output_${sample_output_file}.stdout 2\>_condition_text_output_${sample_output_file}.stderr > ${sample_output_file}.nohup &

      let launched_count=$launched_count+1
      echo $sample_list_file >> $launched_list

      # if we have launched BATCHSIZE, or all of them, wait for this batch to complete, and summarise each file
      let modcount=${launched_count}%$BATCHSIZE
      if [[ (  $modcount == 0 ) || (  ${launched_count} == $sample_count ) ]]; then
         for sample_list_file in `cat $launched_list`; do
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
         launched_list=`mktemp`
      fi
   done

   # create a table from all summaries - one sample per column, one row per taxon
   $GBS_BIN/summarise_hiseq_taxonomy.py --summary_type summary_table $WORKING_FOLDER/*.pickle > ${WORKING_FOLDER}/samples_taxonomy_table.txt

   # write nt database version info
   blastdbcmd -db $blast_database -info > ${WORKING_FOLDER}/blast_db_info.txt 
else
   echo "(skipping blast)"
fi
set +x

echo "*** run_sample_contamination_checks.sh has completed ***"

exit 0
