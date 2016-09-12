#!/bin/bash

function get_opts() {

help_text="
 examples : \n
 ./blast_analyse_samples.sh -n -D /dataset/hiseq/scratch/postprocessing/160706_D00390_0259_BC9BRCANXX.gbs/SQ2567.processed_sample/uneak/tagCounts/ -O /dataset/hiseq/scratch/postprocessing/160706_D00390_0259_BC9BRCANXX.gbs/SQ2567.processed_sample/uneak/blast\n
 ./blast_analyse_samples.sh -n -D /dataset/hiseq/scratch/postprocessing/160829_D00390_0263_BC9NR8ANXX.gbs/SQ0254.processed_sample/uneak/tagCounts/ -O /dataset/hiseq/scratch/postprocessing/160829_D00390_0263_BC9NR8ANXX.gbs/SQ0254.processed_sample/uneak/blast\n
"

SAMPLE_SIZE=500
DRY_RUN=no
OUTPUT_DIR=`pwd`
TASK=blast

while getopts ":nhN:D:O:T:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    N)
      SAMPLE_SIZE=$OPTARG
      ;;
    D)
      DATA_DIR=$OPTARG
      ;;
    O)
      OUTPUT_DIR=$OPTARG
      ;;
    T)
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
}

function check_opts() {
mkdir -p $OUTPUT_DIR
if [ ! -d $OUTPUT_DIR ]; then
   echo "$OUTPUT_DIR does not exist - could not create"
   exit 1
fi
if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi
if [[ $TASK  != "summarise" && $TASK != "blast"  && $TASK != "sample" ]]; then
   echo "task must be blast or summarise"
   exit 1
fi

}


function echo_opts() {
    echo "run to process : $RUN"
    echo "dry run : $DRY_RUN"
    echo "machine : $MACHINE"
    echo "sample : $SAMPLE"
    echo "task : $TASK"
    echo "results will be written to : $OUTPUT_DIR"
}

function configure_env() {
    module load tassel/3/3.0.173
}

function get_sample() {
set -x
    # get number of tags in file
    tag_count=`$GBS_BIN/cat_tag_count.sh -O count $tag_count_file`

    sample_rate=`echo "scale=6; $SAMPLE_SIZE/$tag_count" | bc`
   
    tag_base=`basename $tag_count_file`

    if [ $DRY_RUN == "yes" ]; then
        echo " will execute: 
        FIFO_PREFIX=`mktemp -u`
        FIFO_PREFIX=`basename $FIFO_PREFIX`
        FIFO_PREFIX=/tmp/$FIFO_PREFIX
        fifo=${FIFO_PREFIX}.sampling.fifo
        mkfifo $fifo
        $GBS_BIN/cat_tag_count.sh -O fasta $tag_count_file > $fifo &
        ~/tardis/tardis/tardis.py -d $OUTPUT_DIR -c 999999999 -w -s $sample_rate cat _condition_fasta_input_$fifo \> _condition_fasta_output_$OUTPUT_DIR/${tag_base}_sample.fa
        rm -f $fifo
   (** dry run **)
"
    else
        FIFO_PREFIX=`mktemp -u`
        FIFO_PREFIX=`basename $FIFO_PREFIX`
        FIFO_PREFIX=/tmp/$FIFO_PREFIX
        fifo=${FIFO_PREFIX}.sampling.fifo
        mkfifo $fifo
        $GBS_BIN/cat_tag_count.sh -O fasta $tag_count_file > $fifo &
        ~/tardis/tardis/tardis.py -d $OUTPUT_DIR -c 999999999 -w -s $sample_rate cat _condition_fasta_input_$fifo \> _condition_fasta_output_$OUTPUT_DIR/${tag_base}_sample.fa
        rm -f $fifo
    fi
set +x
}

function run_blast() {
set -x
    tag_base=`basename $tag_count_file`
    sample_file=$OUTPUT_DIR/${tag_base}_sample.fa.gz
    if [ $DRY_RUN == "yes" ]; then
        echo "will execute

        ~/tardis/tardis/tardis.py -w -d $OUTPUT_DIR blastn -query _condition_fasta_input_$sample_file -num_threads 2 -db nt  -evalue 1.0e-10 -dust \'20 64 1\' -max_target_seqs 1 -outfmt  \'7 qseqid sseqid pident evalue staxids sscinames scomnames sskingdoms stitle\' -out _condition_text_output_$OUTPUT_DIR/${tag_base}.out
    "
    else
        ~/tardis/tardis/tardis.py -w -d $OUTPUT_DIR blastn -query _condition_fasta_input_$sample_file -num_threads 2 -db nt  -evalue 1.0e-10 -dust \'20 64 1\' -max_target_seqs 1 -outfmt  \'7 qseqid sseqid pident evalue staxids sscinames scomnames sskingdoms stitle\' -out _condition_text_output_$OUTPUT_DIR/${tag_base}.out
    fi
set +x
}


function summarise() {
set -x
    if [ $DRY_RUN == "yes" ]; then
        echo "will execute

        $GBS_BIN/summarise_hiseq_taxonomy.py $OUTPUT_DIR/*.out.gz
        $GBS_BIN/summarise_hiseq_taxonomy.py --summary_type summary_table $OUTPUT_DIR/*.pickle > $OUTPUT_DIR/blast_frequency_table.txt
        $GBS_BIN/summarise_hiseq_taxonomy.py --summary_type summary_table --measure information $OUTPUT_DIR/*.pickle > $OUTPUT_DIR/blast_information_table.txt
    "
    else
        $GBS_BIN/summarise_hiseq_taxonomy.py $OUTPUT_DIR/*.out.gz
        $GBS_BIN/summarise_hiseq_taxonomy.py --summary_type summary_table $OUTPUT_DIR/*.pickle > $OUTPUT_DIR/blast_frequency_table.txt
        $GBS_BIN/summarise_hiseq_taxonomy.py --summary_type summary_table --measure information $OUTPUT_DIR/*.pickle > $OUTPUT_DIR/blast_information_table.txt
    fi
set +x
}

get_opts $@
check_opts
echo_opts
configure_env

if [ $TASK == "sample" ]; then
    for tag_count_file in $DATA_DIR/*.cnt; do
        get_sample
    done
elif [ $TASK == "summarise" ]; then
    summarise
elif [ $TASK == "blast" ]; then
    for tag_count_file in $DATA_DIR/*.cnt; do
        get_sample
        run_blast &
    done
elif [ $TASK == "summarise" ]; then 
    summarise
fi
