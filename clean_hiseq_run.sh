#!/bin/sh

function get_opts() {
DRY_RUN=no
RUN_ROOT=/dataset/hiseq/active
ARCHIVE_ROOT=/dataset/hiseq/archive/run_archives
SCRATCH_ROOT=/dataset/hiseq/scratch/postprocessing
help_text="
 examples : \n
 ./clean_hiseq_run.sh -n -r 141122_D00390_0212_AC5MUKANXX\n
"

while getopts ":nhr:" opt; do
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
   TASK=""
   if [ $HOSTNAME == "invnaspp03.agresearch.co.nz" ]; then
      RUN_MOUNT=/export/z102/active/hiseq/$RUN   
      FILE_SYSTEM=z102/active/hiseq/$RUN
      if [ ! -d "$RUN_MOUNT" ]; then
         echo "error can't find $RUN_MOUNT"
         exit 1
      fi
      TASK=remove_active
   elif [ $HOSTNAME == "granaspp02.agresearch.co.nz" ]; then
      REPLICA_FILESYSTEM=z202/replica/z102/active/hiseq/$RUN
      RUN_MOUNT=/export/z202/replica/z102/active/hiseq/$RUN
      if [ ! -d "$RUN_MOUNT" ]; then
         echo "error can't find $RUN_MOUNT"
         exit 1
      fi
      TASK=remove_replica
   elif [ $HOSTNAME == "inbfop03.agresearch.co.nz" ]; then
      TASK="link_archive_clean_scratch"
   else
      echo "you should only run this from integrity, gypsy or intrepid"
      exit 1
   fi
}

function do_clean() {
   if [ $TASK == "remove_active" ]; then
      echo "will execute:
rm -rf $RUN_MOUNT/*

zfs set reserv=1M $FILE_SYSTEM
zfs set quota=1M $FILE_SYSTEM 

and the output of 

zfs list -r -t snapshot $FILE_SYSTEM | awk '{print \"zfs destroy \" \$1}' - | grep -v NAME > destroy_${RUN}.sh

i.e. 
"
      zfs list -r -t snapshot $FILE_SYSTEM | awk '{print "zfs destroy " $1}' - | grep -v NAME
      if [ $DRY_RUN == "yes" ]; then
         echo " *** (dry run only ! - not done) ***"
         exit 0
      else
         answer=n
         echo "do you want to continue ? (y/n)"
         read answer
         if [ $answer != "y" ]; then
            echo "OK - quitting"
         else
            echo "executing above..."
            set -x
            rm -rf $RUN_MOUNT/*
            zfs list -r -t snapshot $FILE_SYSTEM | awk '{print "zfs destroy " $1}' - | grep -v NAME > destroy_${RUN}.sh
            source ./destroy_${RUN}.sh
            zfs set reserv=1M $FILE_SYSTEM
            zfs set quota=1M $FILE_SYSTEM
            set +x
         fi
      fi
   elif  [ $TASK == "remove_replica" ]; then
      echo "will execute:
zfs destroy -r z202/replica/z102/active/hiseq/$RUN 
"
      if [ $DRY_RUN == "yes" ]; then
         echo " *** (dry run only ! - not done) ***"
         exit 0
      else
         answer=n
         echo "do you want to continue ? (y/n)"
         read answer
         if [ $answer != "y" ]; then
            echo "OK - quitting"
         else
            echo "executing above..."
            set -x
            zfs destroy -r z202/replica/z102/active/hiseq/$RUN
            set +x
         fi
      fi
   elif [ $TASK == "link_archive_clean_scratch" ]; then
      echo "will execute:
ln -s ${ARCHIVE_ROOT}/${RUN} $RUN_ROOT/${RUN}/archive

"
      echo "(press any key to see list of files under scratch that will be deleted)"
      read 
      find $SCRATCH_ROOT/${RUN}.processed -name "*.fastq.gz" -type f -print | awk '{print "rm -i "  $1}' - | more
      if [ $DRY_RUN == "yes" ]; then
         echo " *** (dry run only ! - not done) ***"
         exit 0
      else
         answer=n
         echo "do you want to continue ? (y/n)"
         read answer
         if [ $answer != "y" ]; then
            echo "OK - quitting"
         else
            echo "executing above..."
            set -x
ln -s ${ARCHIVE_ROOT}/${RUN} $RUN_ROOT/${RUN}/archive
find $SCRATCH_ROOT/${RUN}.processed -name "*.fastq.gz" -type f -exec rm -i {} \; 
            set +x
         fi
      fi
   fi
}

get_opts $@

check_opts

do_clean

