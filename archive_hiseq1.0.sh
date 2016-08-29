#!/bin/sh
# driver script for an associated makefile, used to archive select files of a hiseq run 

function get_opts() {

DRY_RUN=no
RUN_ROOT=/dataset/hiseq/active
ARCHIVE_ROOT=/dataset/hiseq/archive/run_archives
help_text="
 examples : \n
 ./archive_hiseq1.0.sh -n -r 140127_D00390_0027_AH88H8ADXX \n
"

while getopts ":nhr:T:A:B:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    h)
      echo -e $help_text
      exit 0
      ;;
    r)
      RUN=$OPTARG
      ;;
    B)
      RUN_ROOT=$OPTARG
      ;;
    A)
      ARCHIVE_ROOT=$OPTARG
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

RUN_DIR=$RUN_ROOT/$RUN
ARCHIVE_DIR=$ARCHIVE_ROOT/$RUN
if [ ! -d $ARCHIVE_DIR ]; then
   mkdir $ARCHIVE_DIR
fi
}

function check_opts() {
  if [ -z "$RUN" ]; then
    echo "must specify run name using -r option"
    exit 1
  fi
  if [ ! -d "$ARCHIVE_ROOT" ]; then
    echo "ARCHIVE_ROOT $ARCHIVE_ROOT not found "
    exit 1
  fi
  if [ ! -d "$ARCHIVE_DIR" ]; then
    echo "$ARCHIVE_DIR does not exist"
    exit 1
  fi
  if [ ! -d "$RUN_ROOT" ]; then
    echo "$RUN_ROOT does not exist"
    exit 1
  fi
  if [ ! -d "$RUN_DIR" ]; then
    echo "$RUN_DIR does not exist"
    exit 1
  fi
}

function echo_opts() {
  echo DRY_RUN=$DRY_RUN
  echo RUN=$RUN
  echo ARCHIVE_ROOT=$ARCHIVE_ROOT
  echo ARCHIVE_DIR=$ARCHIVE_DIR
  echo RUN_ROOT=$RUN_ROOT
  echo RUN_DIR=$RUN_DIR
}


get_opts $@

check_opts

echo_opts

##### from here inline code to run the processing

cp archive_hiseq1.0.mk $ARCHIVE_DIR
cd $ARCHIVE_DIR 
echo "(logging run to $ARCHIVE_DIR/${RUN}.archivelog)" 
if [ $DRY_RUN != "no" ]; then
   echo "***** dry run only *****"
   set -x
   echo rsync -r -f"+ */" -f"- *" $RUN_DIR/ $ARCHIVE_DIR/
   echo "mkdir $ARCHIVE_DIR/processed"
   make -f archive_hiseq1.0.mk -d --no-builtin-rules -j 8 -n runname=$RUN rundir=$RUN_DIR archivedir=${ARCHIVE_DIR} tempdir=$ARCHIVE_DIR ${ARCHIVE_DIR}/${RUN}.all >> ${RUN}.archivelog 2>&1
else
   rsync -r -f"+ */" -f"- *" $RUN_DIR/ $ARCHIVE_DIR/
   mkdir $ARCHIVE_DIR/processed
   make -f archive_hiseq1.0.mk -d --no-builtin-rules -j 8 runname=$RUN rundir=$RUN_DIR archivedir=${ARCHIVE_DIR} tempdir=$ARCHIVE_DIR ${ARCHIVE_DIR}/${RUN}.all >> ${RUN}.archivelog 2>&1
   set -x
fi
set +x

# make a precis of the log file
make -i -f archive_hiseq1.0.mk ${RUN}.archivelogprecis > /dev/null  2>&1

cat ${RUN}.archivelogprecis

