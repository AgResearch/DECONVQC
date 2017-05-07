#!/bin/sh

#
# this script is used by the make process to check on each step, and also on the entire process
# usage : 
# ./check_uneak_run.sh dirname check_moniker
#
#
dirname=$1
check_moniker=$2
if [ $check_moniker == "global" ]; then
   error_files=`find $dirname -name "*.se" -type f -size +0c -ls`

   if [ -z "$error_files" ]; then
      exit 0
   else
      echo "**** There were errors reported by one or more tassel steps - see below ****"
      echo $error_files
      exit 1
   fi
fi


