#!/bin/sh
#
# this script lists a keyfile from the database   
function get_opts() {

help_text="\n
 this scripts extracts a keyfile from the database \n

 listKeyfile.sh -s sample_name  [-v Tassel version] [-t extract template]\n
\n
 e.g.\n
 listDBKeyfile.sh -s SQ0032 \n
 listDBKeyfile.sh -s SQ0002 -t all \n
 listDBKeyfile.sh -s SQ0032 -v 5 \n
 listDBKeyfile.sh -s SQ2534 -v 5 -f C6K0YANXX \n

"

TASSEL_VERSION=3
FLOWCELL=""
TEMPLATE="default"

while getopts ":nhv:s:k:c:f:t:" opt; do
  case $opt in
    s)
      SAMPLE=$OPTARG
      ;;
    v)
      TASSEL_VERSION=$OPTARG
      ;;
    f)
      FLOWCELL=$OPTARG
      ;;
    t)
      TEMPLATE=$OPTARG
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

}

function check_opts() {
   if [ -z "$GBS_BIN" ]; then
      echo "GBS_BIN not set - quitting"
      exit 1
   fi

   if [ -z $SAMPLE ]; then
      echo "must specify a sample name"
      exit 1
   fi
   if [[ $TASSEL_VERSION != 3 && $TASSEL_VERSION != 5 ]]; then
      echo "Tassel version should be 3 or 5"
      exit 1
   fi
   if [[ $TEMPLATE != "default" && $TEMPLATE != "all" ]]; then
      echo "template should be default or all"
      exit 1
   fi

}


get_opts $@

check_opts


############ process the extract ###############
if [ $TASSEL_VERSION  == "3" ]; then
   if [ -z $FLOWCELL ]; then
      psql -q -U gbs -d agrbrdf -h invincible -v keyfilename=\'$SAMPLE\' -f $GBS_BIN/database/extractKeyfile_${TEMPLATE}.psql 
   else
      psql -q -U gbs -d agrbrdf -h invincible -v keyfilename=\'$SAMPLE\' -f $GBS_BIN/database/extractKeyfile_${TEMPLATE}.psql | egrep -i \($FLOWCELL\|flowcell\)
   fi
else
   if [ -z $FLOWCELL ]; then
      psql -q -U gbs -d agrbrdf -h invincible -v keyfilename=\'$SAMPLE\' -f  $GBS_BIN/database/extractKeyfile5_${TEMPLATE}.psql   
   else
      psql -q -U gbs -d agrbrdf -h invincible -v keyfilename=\'$SAMPLE\' -f  $GBS_BIN/database/extractKeyfile5_${TEMPLATE}.psql | egrep -i \($FLOWCELL\|flowcell\)  
   fi
fi

if [ $? != 0 ]; then
   echo " looks like extract failed - you might need to set up a .pgpass file in your home folder "
   exit 1
fi 
