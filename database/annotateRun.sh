#!/bin/sh
#
# this scripts annotates a run in the database   
# to use it - e.g.
# annotateRun.sh 150630_D00390_0232_AC6K0WANXX 
# jumps through various hoops due to idiosyncracies of 
# \copy and copy
#
function get_opts() {

help_text="\n
      usage : annotateRun.sh [-n] [ -t annotation_type ] -r run_name\n
      examples : \n
      ./annotateRun.sh -n -t KGD_diagnostic -r 170113_D00390_0280_AC9P2FANXX # dry run\n
      ./annotateRun.sh -n -t Plot_link -r 170113_D00390_0280_AC9P2FANXX\n
      ./annotateRun.sh -t Plot_link 170113_D00390_0280_AC9P2FANXX\n
      ./annotateRun.sh -r 170113_D00390_0280_AC9P2FANXX   # all annotations done\n
"

DRY_RUN=no
RUN_NAME=""
TYPE=all

while getopts ":nhir:t:" opt; do
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
    t)
      TYPE=$OPTARG
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

RUN_PATH=/dataset/hiseq/scratch/postprocessing/${RUN_NAME}.gbs
PROCESSED_PATH=/dataset/hiseq/scratch/postprocessing/${RUN_NAME}.processed
PLOTS_PAGE_PATH="/dataset/hiseq/scratch/postprocessing/${RUN_NAME}_plots.html"
PLOTS_PAGE_URL="file://isamba/dataset/hiseq/scratch/postprocessing/${RUN_NAME}_plots.html"
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

if [[ ( $TYPE == "all" ) || ( $TYPE == "KGD_diagnostic" ) ]]; then
   if [ ! -d $RUN_PATH ]; then
      echo $RUN_PATH not found
      exit 1
   fi
elif [ $TYPE == "Plot_link" ]; then
   if [ ! -d $PROCESSED_PATH ]; then
      echo $PROCESSED_PATH not found
      exit 1
   fi
fi

in_db=`$GBS_BIN/database/is_run_in_database.sh $RUN_NAME`
if [ $in_db != "1" ]; then
   echo "$RUN_NAME has not been set up - quitting"
   exit 1 
fi
if [[ ( $TYPE != "KGD_diagnostic" ) && ( $TYPE != "Plot_link" ) && ( $TYPE != "all" ) ]]; then
   echo "annotation type must be either KGD_diagnostic, Plot_link or all"
   exit 1
fi
}

function echo_opts() {
    echo "annotating $TYPE for $RUN_NAME "
}

get_opts $@

check_opts

echo_opts


function add_plot_link() {
   # add a link like file://isamba/dataset/hiseq/scratch/postprocessing/161005_D00390_0268_AC9NRJANXX_plots.html#spreadsheets
   if [ -f $PLOTS_PAGE_PATH ]; then
      echo "select 
   addURL(obid,cast('Link to page with diagnostic plots, spreadsheet summaries etc' as text),
                cast('$PLOTS_PAGE_URL' as text),
                cast('deconvqc' as text),
                true) 
   from biosamplelist
   where listname = '${RUN_NAME}';"  > /tmp/${RUN_NAME}.annotation_link.psql
      if [ $DRY_RUN == "no" ]; then
         psql -U agrbrdf -d agrbrdf -h invincible -f /tmp/${RUN_NAME}.annotation_link.psql
      else
        echo " ** dry run ** will run
         psql -U agrbrdf -d agrbrdf -h invincible -f /tmp/${RUN_NAME}.annotation_link.psql"
      fi
   else 
      echo "annotateRun : no plots file ( $PLOTS_PAGE_PATH )"
   fi
}

function add_kgd_comments() {
   rm -f /tmp/${RUN_NAME}.annotation.psql
   for sample_folder in ${RUN_PATH}/*.processed_sample ; do
      sample_name=`basename $sample_folder .processed_sample`
      file=""
      if [ -f ${sample_folder}/uneak/KGD/kgd.stdout ]; then
         file=${sample_folder}/uneak/KGD/kgd.stdout
      elif [ -f ${sample_folder}/uneak/KGD/kgd.stdout ]; then
         file=${sample_folder}/uneak/KGD/kgd.log
      else
         echo "skipping $sample_name could not find kgd.stdout or kgd.log"
         continue
      fi

      if [ ! -z $file ]; then
         echo "using $file"
         echo "select
   addComment(obid,cast('
KGD diagnostic output for $sample_name :
" >>  /tmp/${RUN_NAME}.annotation.psql

         cat $file | egrep -v "^\[" | sed "s/'/''/g" - >> /tmp/${RUN_NAME}.annotation.psql
         echo "
' as text),
cast('deconvqc' as text),
true)
from
biosamplelist
where listname = '${RUN_NAME}';" >> /tmp/${RUN_NAME}.annotation.psql
      fi
   done
   if [ -f /tmp/${RUN_NAME}.annotation.psql ]; then
      if [ $DRY_RUN == "no" ]; then
         psql -U agrbrdf -d agrbrdf -h invincible -f /tmp/${RUN_NAME}.annotation.psql
      else
        echo " ** dry run ** will run
         psql -U agrbrdf -d agrbrdf -h invincible -f /tmp/${RUN_NAME}.annotation.psql"
      fi
   fi
}


function unblind_kgd_comments() {
   # generate the update script 
   psql -U agrbrdf -d agrbrdf -h invincible  -v run_name=\'${RUN_NAME}\' -f $GBS_BIN/database/gen_update_comments.psql 
   # run the update script 
   psql -U agrbrdf -d agrbrdf -h invincible  -v run_name=\'${RUN_NAME}\' -f /tmp/update_gbs_comments.psql  
}


if [[ ( $TYPE == "all" ) || ( $TYPE == "KGD_diagnostic" ) ]] ; then
   add_kgd_comments
   unblind_kgd_comments
fi

if [[ ( $TYPE == "all" ) || ( $TYPE == "Plot_link" ) ]] ; then
   add_plot_link
fi
