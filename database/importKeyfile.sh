#!/bin/sh
#
function get_opts() {

help_text="\n
 this scripts imports a keyfile to a sample\n

 importKeyfile.sh -s sample_name -k keyfile_base \n
\n
 e.g.\n
 importKeyfile.sh -s SQ0032 -k SQ0032\n
 importKeyfile.sh -s SQ0105 -k SQ0105_ApeKI\n
 importKeyfile.sh -n -s SQ0032 -k SQ0032\n
 importKeyfile.sh -f -s SQ0032 -k SQ0032\n
 jumps through various hoops due to idiosynchracies of\n
 \\copy and copy\n
"

DRY_RUN=no
INTERACTIVE=no
CREATE_FASTQ_COLUMN="no"
FORCE="no"

while getopts ":nhfs:k:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    s)
      SAMPLE=$OPTARG
      ;;
    k)
      KEYFILE_BASE=$OPTARG
      ;;
    f)
      FORCE=yes
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

   if [ ! -f $KEY_DIR/$KEYFILE_BASE.txt ]; then
      echo $KEY_DIR/$KEYFILE_BASE.txt not found
      exit 1
   fi

   if [ -z $SAMPLE ]; then
      echo "must specify a sample name"
      exit 1
   fi

   # check if the keyfile is already in the database
   in_db=`$GBS_BIN/database/is_keyfile_in_database.sh $KEYFILE_BASE`
   if [ $in_db != "0" ]; then
      if [ $FORCE != "yes" ] ; then
         echo "warning $KEYFILE_BASE has previously been imported - will not reimport - force import using -f, or a custom update will be needed (automatic update not yet supported)"
         exit 0
      else
         echo "warning - $KEYFILE_BASE has previously been imported - but proceeding as -f option specified"
      fi 
   fi
   set +x
}

check_file_format() {
   set -x

   # check if file has fastq_link column
   fastq_copy_include=""
   head -1 $KEY_DIR/$KEYFILE_BASE.txt | grep -i fastq_link > /dev/null
   if [ $? == 1 ]; then
      echo "($KEY_DIR/$KEYFILE_BASE.txt does not appear to contain a fastq_link column)"
   else
      fastq_copy_include=",fastq_link"
   fi

   # check if file has control column
   control_copy_include=""
   head -1 $KEY_DIR/$KEYFILE_BASE.txt | grep -i control > /dev/null
   if [ $? == 1 ]; then
      echo "($KEY_DIR/$KEYFILE_BASE.txt does not appear to contain a control column)"
   else
      control_copy_include=",control"
   fi

   # check if file has counter column
   counter_copy_include=""
   head -1 $KEY_DIR/$KEYFILE_BASE.txt | grep -i counter > /dev/null
   if [ $? == 1 ]; then
      echo "($KEY_DIR/$KEYFILE_BASE.txt does not appear to contain a counter column)"
   else
      counter_copy_include=",counter"
   fi

   # check if file has bifo column
   bifo_copy_include=""
   head -1 $KEY_DIR/$KEYFILE_BASE.txt | grep -i bifo > /dev/null
   if [ $? == 1 ]; then
      echo "($KEY_DIR/$KEYFILE_BASE.txt does not appear to contain a bifo column)"
   else
      bifo_copy_include=",bifo"
   fi



}


function echo_opts() {
    echo "importing $KEY_DIR/$KEYFILE_BASE.txt for sample $SAMPLE"
    echo "DRY_RUN=$DRY_RUN"
    echo "FORCE=$FORCE"
}

get_opts $@

check_opts
check_file_format

echo_opts

echo "importing data from $KEY_DIR/$KEYFILE_BASE.txt"
#more $KEY_DIR/$1.txt
if [ $INTERACTIVE == "yes" ]; then
   echo "do you want to continue ? (y/n)
   (you might want to check http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=${SAMPLE}&context=default
   to make sure this keyfile hasn't already been imported)
   "
   answer="n"
   read answer
   if [ "$answer" != "y" ]; then
      echo "OK quitting"
      exit 1
   fi
fi

rm -f /tmp/$KEYFILE_BASE.txt
if [ -f /tmp/$KEYFILE_BASE.txt ]; then
   echo "rm -f /tmp/$KEYFILE_BASE.txt failed - quitting"
   exit 1
fi
rm -f /tmp/$KEYFILE_BASE.psql
if [ -f /tmp/$KEYFILE_BASE.psql ]; then
   echo "rm -f /tmp/$KEYFILE_BASE.psql failed - quitting"
   exit 1
fi

cat $KEY_DIR/$KEYFILE_BASE.txt | iconv -c -t UTF8 | $GBS_BIN/database/sanitiseKeyFile.py > /tmp/$KEYFILE_BASE.txt

echo "
delete from keyfile_temp;

\copy keyfile_temp(Flowcell,Lane,Barcode,Sample,PlateName,PlateRow,PlateColumn,LibraryPrepID${counter_copy_include},Comment,Enzyme,Species,NumberOfBarcodes${bifo_copy_include}${control_copy_include}${fastq_copy_include}) from /tmp/$KEYFILE_BASE.txt with NULL as ''
insert into gbsKeyFileFact (
   biosampleob,
   Flowcell,
   Lane,
   Barcode,
   Sample,
   PlateName,
   PlateRow,
   PlateColumn,
   LibraryPrepID,
   Counter,
   Comment,
   Enzyme,
   Species,
   NumberOfBarcodes,
   Bifo,
   control,
   fastq_link 
   )
select
   s.obid,
   Flowcell,
   Lane,
   Barcode,
   Sample,
   PlateName,
   PlateRow,
   PlateColumn,
   LibraryPrepID,
   Counter,
   Comment,
   Enzyme,
   Species,
   NumberOfBarcodes,
   Bifo,
   control,
   fastq_link
from
   biosampleob as s join keyfile_temp as t on
   s.samplename = :samplename and
   s.sampletype = 'Illumina GBS Library';
" > /tmp/$KEYFILE_BASE.psql

# these next updates add an audit-trail of the import 
echo "
insert into datasourceob(xreflsid, datasourcename, datasourcetype)
select
   :keyfilename,
   :keyfilename,
   'GBS Keyfile'
where not exists (select obid from datasourceob where xreflsid = :keyfilename);

insert into importfunction(xreflsid,datasourceob, ob, importprocedureob)
select 
   bs.samplename || ':' || ds.datasourcename,
   ds.obid,
   bs.obid,
   ip.obid
from 
   (datasourceob ds join biosampleob bs on 
   ds.xreflsid = :keyfilename and bs.samplename = :samplename) join
   importprocedureob ip on ip.xreflsid = 'importKeyfile.sh';
   

" >> /tmp/$KEYFILE_BASE.psql


if [ $DRY_RUN == "no" ]; then
   psql -U agrbrdf -d agrbrdf -h invincible -v keyfilename=\'$KEYFILE_BASE\' -v samplename=\'$SAMPLE\' -f /tmp/$KEYFILE_BASE.psql
   echo updating repository...
   cd $KEY_DIR
   hg add $KEYFILE_BASE.txt
   hg commit -m "importKeyfile.sh added $KEYFILE_BASE.txt" $KEYFILE_BASE.txt
   hg push
else
   echo "keyfile import : will run 
   psql -U agrbrdf -d agrbrdf -h invincible -v keyfilename=\'$KEYFILE_BASE\' -v samplename=\'$SAMPLE\' -f /tmp/$KEYFILE_BASE.psql

   cd $KEY_DIR
   hg add $KEYFILE_BASE.txt
   hg commit -m importKeyfile.sh added $KEYFILE_BASE.txt $KEYFILE_BASE.txt
   hg push"
fi

echo "done (url to access keyfile is http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=${SAMPLE}&context=default )"

