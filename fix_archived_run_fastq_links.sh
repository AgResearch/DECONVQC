#!/bin/sh

function get_opts() {
help_text="
 this script fixes links for runs that have been archived

 examples : \n
 ./fix_archived_run_fastq_links.sh -n -r 140904_D00390_0209_BC4U6YACXX -f C4U6YACXX \n
 ./fix_archived_run_fastq_links.sh -r 140904_D00390_0209_BC4U6YACXX -f C4U6YACXX\n
 ./fix_archived_run_fastq_links.sh -v -r 140904_D00390_0209_BC4U6YACXX -f C4U6YACXX\n
"

DRY_RUN=no
MACHINE=hiseq
VERIFY="no"

while getopts ":nhvr:f:" opt; do
  case $opt in
    n)
      DRY_RUN=yes
      ;;
    v)
      VERIFY=yes
      ;;
    r)
      RUN=$OPTARG
      ;;
    f)
      FCID=$OPTARG
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

HISEQ_ROOT=/dataset/${MACHINE}/active
#ARCHIVE_ROOT=/dataset/${MACHINE}/archive/run_archives
ARCHIVE_ROOT=/bifo/archive/${MACHINE}/run_archives
LINK_FARM=/dataset/hiseq/active/fastq-link-farm
export GBS_BIN
}

function check_opts() {
   if [ -z "$GBS_BIN" ]; then
      echo "GBS_BIN not set - quitting"
      exit 1
   fi
}

function echo_opts() {
   echo "RUN=$RUN"
   echo "FCID=$FCID"
   echo "DRY_RUN=$DRY_RUN"
}

function fix_links() {
   for seqlink in `find $LINK_FARM -type l -name "*${FCID}*fastq*gz" -print`; do
      verify_me=$VERIFY
      target=`readlink -e $seqlink`
      if [ ! -z "$target" ]; then
         echo "warning the link $seqlink  currently points to a target $target - it will be relinked ! "
         if [ $verify_me == "yes" ]; then
            existing_content=`gunzip -c $target | wc`
         fi
      else
         target=`readlink -m $seqlink`
         echo "(unable to verify content as existing target does not exist)"
         verify_me="no"
      fi
      echo "fixing link $seqlink currently pointing to file $target"
      # look for the file under $ARCHIVE_ROOT/$RUN
      base=`basename $target`
      new_target=`find $ARCHIVE_ROOT/$RUN -name $base -print`
      if [ -z "$new_target" ]; then
         echo "ERROR - could not find $base under $ARCHIVE_ROOT/$RUN"
      elif [ ! -s $new_target ]; then
         echo "!! ERROR - the target file $new_target is not a non-zero-length file  !!"
      else  
         echo "
         ===>relinking $seqlink to $new_target

         "
         if [ $DRY_RUN != "no" ]; then
            echo "(*** dry run only - not relinked ***)"
         else
            # do relink
            set -x
            cp -f -s $new_target $seqlink
            set +x
 
            # check that we established the new link
            target_now=`readlink -m $seqlink`
            if [ "$target_now" != "$new_target" ]; then
               echo "!!!!! WARNING the target of the link is now $target_now but it should be $new_target - check integrity of relinking !!!!! "
            fi

            # check contents are the same if asked to
            if [ $verify_me == "yes" ]; then
               new_content=`gunzip -c $new_target | wc`
               if [ "$new_content" != "$existing_content" ]; then
                  echo "!!!!! WARNING wc of old target gave $existing_content, wc of new gives $new_content - check integrity of relinking !!!!! "
               else  
                  echo "** contents of new and old targets look the same, thats good **" 
               fi
            fi
         fi
      fi
   done
set +x
}

get_opts $@
check_opts
echo_opts
fix_links
