#!/bin/sh
#
# this scripts extracts a keyfile   
# to the keyfile folder 
function get_opts() {

help_text="\n
 this scripts extracts a keyfile to a sample\n

 extractKeyfile.sh -s sample_name -k keyfile_name [-v Tassel version] [-c custom_fastq_location]\n
\n
 e.g.\n
 extractKeyfile.sh -s SQ0032 -k SQ0032.txt\n
 extractKeyfile.sh -s SQ0105 -k SQ0105_ApeKI.txt\n
 extractKeyfile.sh -n -s SQ0032 -k SQ0032.txt\n
"

DRY_RUN=no
TASSEL_VERSION=3
CUSTOM_FASTQ_LOCATION=""

while getopts ":nhv:s:k:c:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    s)
      SAMPLE=$OPTARG
      ;;
    k)
      KEYFILE_NAME=$OPTARG
      ;;
    v)
      TASSEL_VERSION=$OPTARG
      ;;
    c)
      CUSTOM_FASTQ_LOCATION=$OPTARG
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

KEY_DIR=/dataset/hiseq/active/key-files
}

function check_opts() {
   if [ -z "$GBS_BIN" ]; then
      echo "GBS_BIN not set - quitting"
      exit 1
   fi
   if [ ! -f $KEY_DIR/$KEYFILE_NAME ]; then
      echo "warning $KEY_DIR/$KEYFILE_NAME not found , its usually already there, but proceeding anyway"
   fi

   if [ -z $SAMPLE ]; then
      echo "must specify a sample name"
      exit 1
   fi

# check if there are uncomitted changes as reported by mercurial - if there are do not extract
# it as we may obliterate these - we probably need to re-import the keyfile
echo "checking for uncomitted updates (as reported by mercurial)..."
pwd=`pwd`
cd $KEY_DIR
hg status | egrep "^M $KEYFILE_NAME"
if [ $? == 0 ]; then
   echo "
   there are uncomitted changes to $KEYFILE_NAME :-( . You will probably need to
      1. commit these and push to the repo
      2. reimport the keyfile to the database
      3. reapply the changes that you made and want to extract
      4. finally, re-extract and commit to the repo

   no extract done ! - quitting
   "
   exit 1
else
   echo "no uncomitted changes found :-) "
fi
cd $pwd

   # if there is a custom fastq location , check it exists 
   if [ ! -z $CUSTOM_FASTA_LOCATION ]; then
      if [ ! -f $CUSTOM_FASTA_LOCATION ]; then
         echo $CUSTOM_FASTA_LOCATION not found 
         exit 1
      fi
   fi
}

function echo_opts() {
    echo "extracting $KEY_DIR/$KEYFILE_NAME for sample $SAMPLE"
    echo "DRY_RUN=$DRY_RUN"
    echo CUSTOM_FASTA_LOCATION=$CUSTOM_FASTA_LOCATION
}

get_opts $@

check_opts

echo_opts


############ process the extract ###############
if [ $DRY_RUN == "no" ]; then
   set -x
   echo "writing keyfile...(backing up existing file to $KEY_DIR/${KEYFILE_NAME}.bu1)"
   rm -f $KEY_DIR/${KEYFILE_NAME}.bu1
   if [ -f $KEY_DIR/${KEYFILE_NAME}.bu1 ]; then
      echo "unable to remove existing backup - quitting"
      exit 1
   fi

   cp $KEY_DIR/${KEYFILE_NAME} $KEY_DIR/${KEYFILE_NAME}.bu1
   if [ ! -f $KEY_DIR/${KEYFILE_NAME}.bu1 ]; then
      echo "unable to create backup file - quitting"
      exit 1
   fi

   #psql -q -U agrbrdf -d agrbrdf -h invincible -v keyfilename=\'$SAMPLE\' -f $GBS_BIN/database/extractKeyfile.psql > $KEY_DIR/${KEYFILE_NAME}
   $GBS_BIN/database/listDBKeyfile.sh -s $SAMPLE -v $TASSEL_VERSION  > $KEY_DIR/${KEYFILE_NAME}

   echo "updating repository..."
   cd $KEY_DIR
   hg pull -u
   hg commit -m "extractKeyfile.sh updated ${KEYFILE_NAME}" ${KEYFILE_NAME} 
   hg push
else
   echo "** Dry run only **"
   echo "will extract the following data to $KEY_DIR/${KEYFILE_NAME}"

   psql -q -U agrbrdf -d agrbrdf -h invincible -v keyfilename=\'$SAMPLE\' -f  $GBS_BIN/database/extractKeyfile.psql

   echo "will execute....

   rm -f $KEY_DIR/${KEYFILE_NAME}.bu1
   if [ -f $KEY_DIR/${KEYFILE_NAME}.bu1 ]; then
      echo  unable to remove existing backup - quitting
      exit 1
   fi

   cp $KEY_DIR/${KEYFILE_NAME} $KEY_DIR/${KEYFILE_NAME}.bu1
   if [ ! -f $KEY_DIR/${KEYFILE_NAME}.bu1 ]; then
      echo unable to create backup file - quitting
      exit 1
   fi

   #psql -q -U agrbrdf -d agrbrdf -h invincible -v keyfilename=\'$SAMPLE\' -f  $GBS_BIN/database/extractKeyfile.psql > $KEY_DIR/${KEYFILE_NAME} 
   $GBS_BIN/database/listDBKeyfile.sh -s $SAMPLE -v $TASSEL_VERSION  > $KEY_DIR/${KEYFILE_NAME}

   echo updating repository...
   cd $KEY_DIR
   hg pull -u
   hg commit -m extractKeyfile.sh updated ${KEYFILE_NAME} ${KEYFILE_NAME}
   hg push"
fi
