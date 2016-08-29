#!/bin/sh

# creates links to a key file in a GBS processing folder
# The argument is the folder in which to link - e.g.
# /dataset/hiseq/scratch/postprocessing/150925_D00390_0235_BC6K0YANXX.gbs_in_progress/SQ0123.sample_in_progress/uneak_in_progress/key
KEY_ROOT=/dataset/hiseq/active/key-files
echo "linking key files in $1"
set -x
key_base=`psql -U agrbrdf -d agrbrdf -h invincible -v gbs_key_link_folder="'$1'" -f $GBS_BIN/database/get_keyfilename.psql -q | sed 's/ //g' -`
if [ ! -f $KEY_ROOT/$key_base ]; then
   echo "link_key_files.sh : ERROR keyfile  $KEY_ROOT/$key_base does not exist"
   exit 1
fi

#cp -s $KEY_ROOT/$key_base $1/$key_base  # this links the original keyfile. OK-ish except for Q/C we only want to GBS the current flowcell 
                                         # (and many keyfiles refer to cumulative runs of a library across many flowcells)  
fcid=`echo $1 | awk -F/ '{print $6}' -`
libname=`echo $1 | awk -F/ '{print $7}' -`
fcid=`echo $fcid | awk -F. '{print $1}' -`
libname=`echo $libname | awk -F. '{print $1}' -`
fcid=`echo $fcid | awk -F_ '{print substr($4,2)}' -`

$GBS_BIN/database/listDBKeyfile.sh -s $libname -f $fcid > $1/$key_base
set +x

exit 0
