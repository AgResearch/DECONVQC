#!/bin/sh
#
# this script updates the sample-sheet in the database by 
# deleting and re-importing 
#
function get_opts() {

help_text="\n
      usage : updateSampleSheet.sh -r run_name\n
      example (dry run) : ./updateSampleSheet.sh -n -r 170207_D00390_0282_ACA7WHANXX\n
      example           : ./updateSampleSheet.sh  -r 170207_D00390_0282_ACA7WHANXX\n
"

DRY_RUN=no
RUN_NAME=""

while getopts ":nhr:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    i)
      INTERACTIVE=yes
      ;;
    r)
      RUN_NAME=$OPTARG
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

RUN_PATH=/dataset/hiseq/active/$RUN_NAME
}

function check_opts() {
if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - quitting"
   exit 1
fi

if [ -z "$RUN_NAME" ]; then
   echo -e $help_text
   exit 1
fi

if [ ! -d $RUN_PATH ]; then
   echo $RUN_PATH not found
   exit 1
fi
if [ ! -f $RUN_PATH/SampleSheet.csv ]; then
   echo $RUN_PATH/SampleSheet.csv not found
   exit 1
fi
in_db=`$GBS_BIN/database/is_run_in_database.sh $RUN_NAME`
if [ $in_db == "0" ]; then
   echo "$RUN_NAME is not in the database - quitting"
   exit 1 
fi
}

function echo_opts() {
    echo "importing $RUN_NAME from $RUN_PATH"
    echo "DRY_RUN=$DRY_RUN"
}

get_opts $@

check_opts

echo_opts

## from here , process the import

rm -f /tmp/${RUN_NAME}_update.txt
if [ -f /tmp/${RUN_NAME}_update.txt ]; then
   echo "rm -f /tmp/${RUN_NAME}_update.txt failed - quitting"
   exit 1
fi
rm -f /tmp/${RUN_NAME}_update.psql
if [ -f /tmp/${RUN_NAME}_update.psql ]; then
   echo "rm -f /tmp/${RUN_NAME}_update.psql failed - quitting"
   exit 1
fi


# parse the sample sheet
#cp $RUN_ROOT/${RUN_NAME}/SampleSheet.csv /tmp/${RUN_NAME}.txt
#awk -F, '{if(NF>5)print}' ${RUN_PATH}/SampleSheet.csv  > /tmp/${RUN_NAME}.txt
cat ${RUN_PATH}/SampleSheet.csv | $GBS_BIN/database/sanitiseSampleSheet.py -r $RUN_NAME > /tmp/${RUN_NAME}_update.txt

# check we got something non-trivial
if [ ! -s /tmp/${RUN_NAME}_update.txt ]; then
   echo "error parsed sample sheet /tmp/${RUN_NAME}_update.txt is missing or empty"
   exit 1
fi


echo "
delete from samplesheet_temp;

delete from hiseqSampleSheetFact where biosamplelist =
(select obid from biosamplelist where listname = '$RUN_NAME');


\copy samplesheet_temp from /tmp/${RUN_NAME}_update.txt with  CSV HEADER

insert into hiseqSampleSheetFact (
   biosamplelist ,
   FCID ,
   Lane ,
   SampleID ,
   SampleRef ,
   SampleIndex ,
   Description ,
   Control ,
   Recipe,
   Operator ,
   SampleProject ,
   sampleplate,
   samplewell,
   downstream_processing)
select
   obid,
   FCID ,
   Lane ,
   SampleID ,
   SampleRef ,
   SampleIndex ,
   Description ,
   Control ,
   Recipe,
   Operator ,
   SampleProject, 
   sampleplate,
   samplewell ,
   downstream_processing
from 
   bioSampleList as s join samplesheet_temp as t
   on s.listName = :run_name and 
   t. sampleid is not null;

" > /tmp/${RUN_NAME}_update.psql

if [ $DRY_RUN == "no" ]; then
   psql -U agrbrdf -d agrbrdf -h invincible -v run_name=\'${RUN_NAME}\' -f /tmp/${RUN_NAME}_update.psql
else
   echo " will run 
   psql -U agrbrdf -d agrbrdf -h invincible -v run_name=\'${RUN_NAME}\' -f /tmp/${RUN_NAME}_update.psql"
fi


echo "done (URL to access run is http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=${RUN_NAME}&context=default )"
