#!/bin/sh
#
# this scripts sets up a run in the database   
# to use it - e.g.
# addRun.sh 150630_D00390_0232_AC6K0WANXX 
# jumps through various hoops due to idiosyncracies of 
# \copy and copy
#
function get_opts() {

help_text="\n
      usage : addRun.sh -r run_name\n
      example (dry run) : ./addRun.sh -n -r 151016_D00390_0236_AC6JURANXX\n
      example           : ./addRun.sh -r 151016_D00390_0236_AC6JURANXX\n
      example           : ./addRun.sh -r 171026_M02412_0043_000000000-D2N2Ua -m miseq
"

DRY_RUN=no
RUN_NAME=""
MACHINE=hiseq

while getopts ":nhr:m:" opt; do
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
    m)
      MACHINE=$OPTARG
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
RUN_PATH=/dataset/${MACHINE}/active/$RUN_NAME
CANONICAL_RUN_PATH=/dataset/hiseq/active/$RUN_NAME
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

if [[ ( $MACHINE == "miseq" ) && ( ! -h $CANONICAL_RUN_PATH ) ]]; then
   echo error , miseq run and shortcut $CANONICAL_RUN_PATH not found
   exit 1
fi

if [ ! -f $RUN_PATH/SampleSheet.csv ]; then
   echo $RUN_PATH/SampleSheet.csv not found
   exit 1
fi

in_db=`$GBS_BIN/database/is_run_in_database.sh $RUN_NAME`
if [ $in_db != "0" ]; then
   echo "$RUN_NAME has already been added - quitting"
   exit 1 
fi

# machine must be miseq or hiseq
if [[ ( $MACHINE != "hiseq" ) && ( $MACHINE != "miseq" ) ]]; then
    echo "machine must be miseq or hiseq"
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

rm -f /tmp/${RUN_NAME}.txt
if [ -f /tmp/${RUN_NAME}.txt ]; then
   echo "rm -f /tmp/${RUN_NAME}.txt failed - quitting"
   exit 1
fi
rm -f /tmp/${RUN_NAME}.psql
if [ -f /tmp/${RUN_NAME}.psql ]; then
   echo "rm -f /tmp/${RUN_NAME}.psql failed - quitting"
   exit 1
fi


# parse the sample sheet
#cp $RUN_ROOT/${RUN_NAME}/SampleSheet.csv /tmp/${RUN_NAME}.txt
#awk -F, '{if(NF>5)print}' ${RUN_PATH}/SampleSheet.csv  > /tmp/${RUN_NAME}.txt
set -x
cat ${RUN_PATH}/SampleSheet.csv | $GBS_BIN/database/sanitiseSampleSheet.py -r $RUN_NAME > /tmp/${RUN_NAME}.txt
set +x

# check we got something non-trivial
if [ ! -s /tmp/${RUN_NAME}.txt ]; then
   echo "error parsed sample sheet /tmp/${RUN_NAME}.txt is missing or empty"
   exit 1
fi


echo "


insert into bioSampleList (xreflsid, listName, listComment)
values(:run_name, :run_name, 'AgResearch Hiseq Run');

delete from samplesheet_temp;


\copy samplesheet_temp from /tmp/${RUN_NAME}.txt with  CSV HEADER

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
   downstream_processing,
   basespace_project)
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
   downstream_processing,
   basespace_project
from 
   bioSampleList as s join samplesheet_temp as t
   on s.listName = :run_name and 
   t. sampleid is not null;

insert into biosampleob(xreflsid, samplename, sampledescription, sampletype)
select distinct
   SampleID,
   SampleID,
   description,
   case when t.downstream_processing = 'GBS' then 'Illumina GBS Library'
   else 'Illumina Library'
   end
from
   samplesheet_temp t where
   sampleid is not null and 
   not exists (select obid from biosampleob where samplename = t.SampleID);

insert into biosamplelistmembershiplink (biosamplelist, biosampleob)
select 
    l.obid,
    s.obid
from 
    (biosampleob as s join samplesheet_temp as t on 
    t.sampleid = s.samplename ) join biosamplelist as l on 
    l.listname = :run_name  
except
select
    biosamplelist, 
    biosampleob
from
    biosamplelistmembershiplink as m join biosamplelist as l on
    m.biosamplelist = l.obid and
    l.listname = :run_name ;
" > /tmp/${RUN_NAME}.psql

if [ $DRY_RUN == "no" ]; then
   psql -U agrbrdf -d agrbrdf -h invincible -v run_name=\'${RUN_NAME}\' -f /tmp/${RUN_NAME}.psql
else
   echo " will run 
   psql -U agrbrdf -d agrbrdf -h invincible -v run_name=\'${RUN_NAME}\' -f /tmp/${RUN_NAME}.psql"
fi


echo "done (URL to access run is http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=${RUN_NAME}&context=default )"
