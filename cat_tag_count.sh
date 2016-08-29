#!/bin/bash

#reference:
# https://bytebucket.org/tasseladmin/tassel-5-source/wiki/docs/TasselPipelineGBS.pdf
# /programs/tassel/run_pipeline.pl -fork1 -BinaryToTextPlugin
# -i tagCounts/rice.cnt -o tagCounts/rice_cnt.txt -t TagCounts
# -endPlugin -runfork1

# convenience wrapper to cat a tag-count file 
GBS_BIN=/bifo/active/hiseq/bin/hiseq_pipeline

function get_opts() {

help_text="
 wrapper to tassel function, to cat a tag count file to stdout
 
 (stdout / stderr of the process itself is written to /tmp/*.cat_tag_count_stderr)
 
 examples : \n
 ./cat_tag_count.sh /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt 
 ./cat_tag_count.sh -O fasta /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt 
"

FORMAT="text"
while getopts ":hO:" opt; do
  case $opt in
    h)
      echo -e $help_text
      exit 0
      ;;
    O)
      FORMAT=$OPTARG
      shift $((OPTIND-1))
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
infile=$1
# we might need to join together bits of file names if they have embedded spaces
shift
while [ ! -z "$1" ]; do
   infile="$infile $1"
   shift
done
}

function check_opts() {
  if [ -z "$infile" ]; then
    echo "must specify an input file "
    exit 1
  fi
  if [ ! -f "$infile" ]; then
    echo "$infile not found"
    exit 1
  fi
  if [[ $FORMAT != "text" && $FORMAT != "fasta" ]]; then
    echo "FORMAT must be text or fasta"
    exit 1
  fi

  # tassel cannot handle files with spaces in them - we will need to make a shortcut
  #newname=""
  echo "$infile" | grep " " > /dev/null 2>&1 
  remove_temp=0
  if [ $? == 0 ]; then
     #despaced_name=`echo "$infile" | sed 's/ /_/g' -`
     #newname=`basename $despaced_name`
     #rm -f /tmp/$newname
     prefix=`mktemp -u`
     prefix=`basename $prefix`
     temp_name=/tmp/$prefix.cnt
     ln -s "$infile" $temp_name
     infile=$temp_name 
     remove_temp=1
  fi
}

# get and check opts
get_opts $@
check_opts


# now cat the file 

# set up a fifo to pass to tassel as its outfile
FIFO_PREFIX=`mktemp -u` 
FIFO_PREFIX=`basename $FIFO_PREFIX` 
FIFO_PREFIX=/tmp/$FIFO_PREFIX 
f1=${FIFO_PREFIX}.f1 
mkfifo $f1 

# set up a file for the stdout / stderr of this run
OUT_PREFIX=`mktemp -u`
OUT_PREFIX=`basename $OUT_PREFIX`
OUT_PREFIX=/tmp/$OUT_PREFIX
errfile=${OUT_PREFIX}.cat_tag_count_stderr


#load tassel3
module load tassel/3

#start tassel process to write text to fifo, running in background
nohup run_pipeline.pl -fork1 -BinaryToTextPlugin  -i "$infile" -o $f1 -t TagCounts -endPlugin -runfork1 >$errfile 2>&1 &

#start process to read fifo and list to stdout
if [ $FORMAT == "text" ]; then
   cat <$f1
elif [ $FORMAT == "fasta" ]; then
   cat <$f1 | $GBS_BIN/tags_to_fasta.py
fi

# clean up
rm $f1

if [ $remove_temp == 1 ]; then
   rm -f $temp_name
fi

