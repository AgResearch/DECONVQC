#!/bin/sh
#
function get_opts() {

help_text="\n

Example : 

./updateFastqLocations.sh -n -s SQ0124 -k SQ0124 -r 151016_D00390_0236_AC6JURANXX -f C6JURANXX -l 1 

"

DRY_RUN=no
INTERACTIVE=no
MACHINE=hiseq

while getopts ":nhr:s:k:f:l:m:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    s)
      SAMPLE=$OPTARG
      ;;
    r)
      RUN_NAME=$OPTARG
      ;;
    k)
      KEYFILE_BASE=$OPTARG
      ;;
    f)
      FLOWCELL_NAME=$OPTARG
      ;;
    m)
      MACHINE=$OPTARG
      ;;
    l)
      LANE=$OPTARG
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
PROCESSED_ROOT=/dataset/${MACHINE}/scratch/postprocessing/${RUN_NAME}.processed
LINK_FARM_ROOT=/dataset/hiseq/active/fastq-link-farm
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

   if [ -z $FLOWCELL_NAME ]; then
      echo "must specify a flowcell name"
      exit 1
   fi

   if [ -z $LANE ]; then
      echo "must specify a lane number"
      exit 1
   fi

   if [ -z $RUN_NAME ]; then
      echo "must specify a run name"
      exit 1
   fi

   if [ ! -d $PROCESSED_ROOT  ]; then
      echo "$PROCESSED_ROOT not found"
      exit 1
   fi

   if [[ ( $MACHINE != "hiseq" ) && ( $MACHINE != "miseq" ) ]]; then
      echo "machine must be miseq or hiseq"
      exit 1
   fi

}


function echo_opts() {
    echo DRY_RUN=$DRY_RUN
    echo "updating $KEY_DIR/$KEYFILE_BASE.txt for sample $SAMPLE"
    echo FLOWCELL_NAME=$FLOWCELL_NAME
    echo LANE=$LANE
}

function get_gbs_list() {
   if [ -f $PROCESSED_ROOT/$SAMPLE.gbslist ]; then
      echo "** using existing list $PROCESSED_ROOT/$SAMPLE.gbslist **"
   else
      echo "** building $PROCESSED_ROOT/$SAMPLE.gbslist **"
      filename_pattern=`psql -U agrbrdf -d agrbrdf -h invincible -v run=\'$RUN_NAME\' -v sample=\'$SAMPLE\' -v processed_root=\'$PROCESSED_ROOT\' -v lane=$LANE -f $GBS_BIN/database/get_fastq_filename_pattern.psql -q`
      set -x
      find $PROCESSED_ROOT/bcl2fastq/*/ -name "*.fastq.gz" -print  | egrep  $filename_pattern > $PROCESSED_ROOT/$SAMPLE.gbslist
      set +x
      if [ ! -s $PROCESSED_ROOT/$SAMPLE.gbslist  ]; then
         echo "*** error - could not find any sequence files for $SAMPLE under $PROCESSED_ROOT using $filename_pattern ***"
         rm $PROCESSED_ROOT/$SAMPLE.gbslist
         exit 1
      fi
   fi
}

get_opts $@

check_opts

echo_opts

get_gbs_list

echo "updating fastq locations in $KEY_DIR/$KEYFILE_BASE.txt for lane $LANE"
echo "using "
for listfile in $PROCESSED_ROOT/*$SAMPLE*.gbslist; do
   echo "===>"$listfile 
   cat $listfile
done

# process the listfile to set up links
echo "setting up link farm links"
for listfile in $PROCESSED_ROOT/*$SAMPLE*.gbslist; do
   echo "processing listfile $listfile"
   for fastqfile in `cat $listfile | grep L00${LANE}`; do
      echo "processing fastqfile $fastqfile"
      #new_path=`cat $listfile | sed 's/_in_progress//g' -`
      new_path=`echo $fastqfile | sed 's/_in_progress//g' -`
      if [ ! -f $new_path ]; then
         echo "ERROR $new_path not found - quitting"
         exit 1
      fi

      link_path=$LINK_FARM_ROOT/${SAMPLE}_${FLOWCELL_NAME}_s_${LANE}_fastq.txt.gz
  
      if [ -h $link_path ]; then
         ls -l $link_path
         echo "warning link_path $link_path already exists as above - will update it"
         rm $link_path
      fi
      if [ ! -h $link_path ]; then
         if [ $DRY_RUN == "no" ]; then
            set -x
            cp -i -s $new_path $LINK_FARM_ROOT/${SAMPLE}_${FLOWCELL_NAME}_s_${LANE}_fastq.txt.gz
            psql -U agrbrdf -d agrbrdf -h invincible -v flowcell="'${FLOWCELL_NAME}'" -v keyfilename="'${KEYFILE_BASE}'" -v lane=$LANE -v fastqlink="'${link_path}'" -f $GBS_BIN/database/updateFastQLocationInKeyFile.psql
         else
            echo "cp -i -s $new_path $LINK_FARM_ROOT/${SAMPLE}_${FLOWCELL_NAME}_s_${LANE}_fastq.txt.gz"
            echo "psql -U agrbrdf -d agrbrdf -h invincible -v flowcell=\"'${FLOWCELL_NAME}'\" -v keyfilename=\"'${KEYFILE_BASE}'\" -v lane=$LANE -v fastqlink=\"'${link_path}'\" -f $GBS_BIN/database/updateFastQLocationInKeyFile.psql"
         fi
      else
         echo "ERROR : failed updating link path $link_path  ! Something has gone wrong  - quitting"
         exit 1
      fi
   done
done

echo "done"
echo "(you might want to check http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=${SAMPLE}&context=default)"

