#!/bin/sh

# creates links to a key file in a GBS processing folder
# The argument is the folder in which to link - e.g.
#### /dataset/hiseq/scratch/postprocessing/150925_D00390_0235_BC6K0YANXX.gbs_in_progress/SQ0123.sample_in_progress/uneak_in_progress/key
#    /dataset/hiseq/scratch/postprocessing/170413_D00390_0295_BCA5EWANXX.gbs_in_progress/SQ0419.sample_in_progress/uneak_in_progress/PstI.enzyme/key
#    /dataset/hiseq/scratch/postprocessing/170511_D00390_0302_BCA92MANXX.gbs/SQ0451.processed_sample/uneak/PstI.PstI.enzyme


KEY_ROOT=/dataset/hiseq/active/key-files
echo "linking key files in $1"
set -x
key_base=`psql -U agrbrdf -d agrbrdf -h invincible -v gbs_key_link_folder="'$1'" -f $GBS_BIN/database/get_keyfilename.psql -q | sed 's/ //g' -`
if [ ! -f $KEY_ROOT/$key_base ]; then
   echo "link_key_files.sh : ERROR keyfile  $KEY_ROOT/$key_base does not exist"
   exit 1
fi

fcid=`echo $1 | awk -F/ '{print $6}' -`
libname=`echo $1 | awk -F/ '{print $7}' -`
fcid=`echo $fcid | awk -F. '{print $1}' -`
libname=`echo $libname | awk -F. '{print $1}' -`
fcid=`echo $fcid | awk -F_ '{print substr($4,2)}' -`

cohort=`echo $1 | awk -F/ '{print $9}' -`
enzyme=`echo $cohort | awk -F. '{print $2}' -`
gbs_cohort=`echo $cohort | awk -F. '{print $1}' -`

$GBS_BIN/database/listDBKeyfile.sh -s $libname -f $fcid -e $enzyme -g $gbs_cohort > $1/$key_base
set +x

exit 0
