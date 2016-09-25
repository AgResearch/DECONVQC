#!/bin/bash

#reference:
# https://bytebucket.org/tasseladmin/tassel-5-source/wiki/docs/TasselPipelineGBS.pdf
# /programs/tassel/run_pipeline.pl -fork1 -BinaryToTextPlugin
# -i tagCounts/rice.cnt -o tagCounts/rice_cnt.txt -t TagCounts
# -endPlugin -runfork1

# convenience wrapper to cat a tag-count file 

function get_opts() {

help_text="
 wrapper to tassel function, to cat a tag count file to stdout
 
 (stdout / stderr of the process itself is written to /tmp/*.cat_tag_count_stderr)
 
 examples : \n
 # just list the raw text tag file
 ./cat_tag_count.sh /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
 # produce a redundant fasta listing of tags (i.e. each is listed as a sequence N times, N its tag count)
 ./cat_tag_count.sh -O fasta /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
 # print out the total count of all tags 
 ./cat_tag_count.sh -O count /dataset/hiseq/scratch/postprocessing/151016_D00390_0236_AC6JURANXX.gbs/SQ0124.processed_sample/uneak/tagCounts/G88687_C6JURANXX_1_124_X4.cnt \n
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
  if [ -z "$GBS_BIN" ]; then
    echo "GBS_BIN not set - quitting"
    exit 1
  fi

  if [ -z "$infile" ]; then
    echo "must specify an input file "
    exit 1
  fi
  if [ ! -f "$infile" ]; then
    echo "$infile not found"
    exit 1
  fi
  if [[ $FORMAT != "text" && $FORMAT != "fasta"  && $FORMAT != "count" ]]; then
    echo "FORMAT must be text , fasta or count"
    exit 1
  fi

  # tassel cannot handle files with spaces in them - we will need to make a shortcut
  #newname=""
  remove_temp=0
  echo "$infile" | grep " " > /dev/null 2>&1 
  if [ $? == 0 ]; then
     nametmpdir=`mktemp --tmpdir=/tmp -d XXXXXXXXXXXXXX.cat_tag_count_links`
     temp_name=`mktemp --tmpdir=$nametmpdir`
     rm -f $temp_name
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
tmpdir=`mktemp --tmpdir=/tmp -d XXXXXXXXXXXXXX.cat_tag_count_fifos`
fifo=`mktemp --tmpdir=$tmpdir`
rm -f $fifo
mkfifo $fifo

# set up a file for the stdout / stderr of this run
OUT_PREFIX=`mktemp -u`
OUT_PREFIX=`basename $OUT_PREFIX`
OUT_PREFIX=/tmp/$OUT_PREFIX
errfile=`mktemp --tmpdir=/tmp XXXXXXXXXXXXXX.cat_tag_count_stderr`


#load tassel3
module load tassel/3

#start tassel process to write text to fifo, running in background
nohup run_pipeline.pl -fork1 -BinaryToTextPlugin  -i "$infile" -o $fifo -t TagCounts -endPlugin -runfork1 >$errfile 2>&1 &

#start process to read fifo and list to stdout
if [ $FORMAT == "text" ]; then
   cat <$fifo
elif [ $FORMAT == "count" ]; then
   awk '{ if(NF == 3) {sum += $3} } END { print sum }' $fifo
elif [ $FORMAT == "fasta" ]; then
   cat <$fifo | $GBS_BIN/tags_to_fasta.py
fi

# clean up
rm -f $fifo
rmdir $tmpdir

if [ $remove_temp == 1 ]; then
   rm -f $temp_name
   rmdir $nametmpdir
fi

