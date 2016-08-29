#
# Makefile to archive hiseq run  
#***************************************************************************************
# changes 
#***************************************************************************************
# 
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
# tips on handling filenames with spaces in make : 
#     http://www.cmcrossroads.com/article/gnu-make-meets-file-names-spaces-them 
#     http://stackoverflow.com/questions/9838384/can-gnu-make-handle-filenames-with-spaces
#
#
#*****************************************************************************************
# examples  
#*****************************************************************************************
#  make -f archive_hiseq1.0.mk -d --no-builtin-rules -j 8 -n rundir=/dataset/hiseq/active/140127_D00390_0027_AH88H8ADXX archivedir=/dataset/hiseq/archive/run_archives/140127_D00390_0027_AH88H8ADXX tempdir=/dataset/hiseq/archive/run_archives/140127_D00390_0027_AH88H8ADXX /dataset/hiseq/archive/run_archives/140127_D00390_0027_AH88H8ADXX/140127_D00390_0027_AH88H8ADXX.all
#
# (this makefile is usually run by the associated shell script however)
#
#
# ******************************************************************************************
# initialise project specific variables - these are usually overridden by command-line settings as above
# ******************************************************************************************
rundir=/not set
runname=not set
archivedir=/not set
tempdir=/not set
processing_root=/dataset/hiseq/scratch/postprocessing


# ******************************************************************************************
# initialise lists of file targets 
# ******************************************************************************************
# methods needed as part of handling filenames with spaces
s+ = $(subst \ ,+,$1)
+s = $(subst +,\ ,$1)
csv_files := $(shell (cd $(rundir); find . -name "*.csv" -print | sed 's/ /+/g' -))
xml_files := $(shell (cd $(rundir); find . -name "*.xml" -print | sed 's/ /+/g' -))
log_files := $(wildcard $(processing_root)/$(runname)*.log)  

# "fastq_files"  are the legacy files under the run folder, for a few runs where
# we ran the offline basecaller
fastq_files := $(shell (cd $(rundir); find . -name "*.fastq.*" -print | sed 's/ /+/g' -))

# "processed_fastq_files" are those from the recent processing, where we run bcl2fastq
# , generating fastq files under the scratch tier
processed_fastq_files := $(shell (cd $(processing_root)/$(runname).processed; find . -name "*.fastq.gz" -print | sed 's/ /+/g' -))

# edit these groups of filenames so that they are the target names 
# in the archive. The rule can work out what to copy from these
csv_files :=  $(addprefix $(archivedir)/, $(csv_files))
xml_files :=  $(addprefix $(archivedir)/, $(xml_files))
fastq_files :=  $(addprefix $(archivedir)/, $(fastq_files))
processed_fastq_files :=  $(addprefix processed_$(archivedir)/, $(processed_fastq_files))

#*****************************************************************************************
# from here are the targets and rules
#*****************************************************************************************


###############################################
# top level phony test targets  (used for various testing / debugging)
###############################################

###############################################
# top level target "logprecis" . This extracts from the log file the 
# relevant commands that were run, in a readable order 
# - run this after the actual build has been completed
###############################################
%.archivelogprecis: %.archivelog
	echo "file copying" > $*.archivelogprecis
	echo "------------" >> $*.archivelogprecis
	egrep "^cp -p" $*.archivelog >> $*.archivelogprecis
	egrep "^dir\=.*cp -p" $*.archivelog >> $*.archivelogprecis

	echo "file listing" >> $*.archivelogprecis
	echo "------------" >> $*.archivelogprecis
	egrep "^ls -slt" $*.archivelog >> $*.archivelogprecis

	echo "waiting" >> $*.archivelogprecis
	echo "-------" >> $*.archivelogprecis
	egrep "^while" $*.archivelog >> $*.archivelogprecis

###############################################
# top level phony target "all"  - this is the one thats usually used 
###############################################
.PHONY : %.all 
%.all: $(archivedir)/original_files_listing.txt $(csv_files) $(xml_files) $(fastq_files) $(processed_fastq_files)
	echo "making all targets"
	cp -p $(log_files) $(archivedir)/..

###############################################
# how to make the listing of original files in the build dir
###############################################
$(archivedir)/original_files_listing.txt:
	date >> $@
	echo "original files listing" >> $@
	echo "======================" >> $@
	ls -Rl $(rundir) >> $@

###############################################
# how to archive data files 
# (slight complication due to the presence of filenames with spaces , in the hiseq folders)
###############################################
#$(archivedir)/%:  $(rundir)/%
.SECONDEXPANSION:
$(archivedir)/%:  $$(call +s,$(rundir)/$$*)
	cp -pRL "$<" $(call +s, $@) 
.SECONDEXPANSION:
processed_$(archivedir)/%:  $$(call +s,$(processing_root)/$(runname).processed/$$*)
	dir=`dirname $*`; mkdir -p $(archivedir)/processed/$$dir ; cp -pRL "$(processing_root)/$(runname).processed/$*" $(call +s, $(archivedir)/processed/$$dir)



##############################################
# specify the "intermediate" files to keep - i.e. actually these are the archived files
##############################################
.PRECIOUS: (archivedir)/original_files_listing.txt $(archivedir)/% 



##############################################
# cleaning - not yet doing this using make  
##############################################
.PHONY : clean
clean:
	echo "no cleaning configured" 
