#
# Hiseq processing pipeline version 1 
#***************************************************************************************
# changes 
#***************************************************************************************
# 
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#
# Note - you should avoid making your targets in the same folder as your source data (in case you overwrite or clean up
# something important). Create an empty build folder, and then your target to make is empty_build_folder/animal_name.all    
#
#*****************************************************************************************
# examples  
#*****************************************************************************************
#
# ******************************************************************************************
# initialise project specific variables - these are usually overridden by command-line settings as above
# ******************************************************************************************
mytmp=/tmp
run=
#
# ******************************************************************************************
# other variables (not project specific)
# ******************************************************************************************
RUN_TARDIS=tardis.py
RUN_FASTQC=fastqc
RUN_BCL2FASTQ=/usr/local/bin/bcl2fastq 
RUN_CONTAMINATION_CHECK=$(GBS_BIN)/run_sample_contamination_checks.sh
RUN_MAPPING_PREVIEW=$(GBS_BIN)/run_mapping_preview.sh

# variables for tardis and other apps
machine=hiseq
hiseq=400000 .00005
miseq=10000 .002
#SAMPLE_RATE=.00005 # hiseq use e.g. .002 for miseq
#CHUNK_SIZE=400000 # hiseq - use e.g. 10000 for miseq
adapters_file1=/usr/lib64/bcl2fastq-1.8.4/share/bcl2fastq-1.8.4/adapters/TruSeq_r1.fa
adapters_file2=/usr/lib64/bcl2fastq-1.8.4/share/bcl2fastq-1.8.4/adapters/TruSeq_r2.fa


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
%.logprecis: %.log
	echo "bcl2fastq" > $*.logprecis 
	echo "---------" >> $*.logprecis 
	egrep "bcl2fastq" $*.log >> $*.logprecis

	echo "mkdir" >> $*.logprecis
	echo "-----" >> $*.logprecis
	egrep "mkdir" $*.log >> $*.logprecis

	echo "file linking" >> $*.logprecis
	echo "------------" >> $*.logprecis
	egrep "^ln -s" $*.log >> $*.logprecis

	echo "move in_progress to done" >> $*.logprecis
	echo "------------------------" >> $*.logprecis
	egrep "^mv " $*.log | grep "in_progress" >> $*.logprecis


###############################################
# top level phony target "versions"  - output versions of all tools 
# - note , you need to tell make to ignore errors 
# for this target - for some tools , the only way to get a version
# string is to run them with options that provoke an error
# Where useful, this reports the package name as well 
# as getting the tool to report its version.
# (in some cases e.g. bamtools this is all the version
# info there is as the tool itself doesn't report any
# version info)
# (not all the tools that were used are installed 
# as packages currently )
###############################################
.PHONY : versions.log
versions.log:
	echo "Tool versions : " > versions.log
	echo "fastqc"  >> versions.log
	echo "------"  >> versions.log
	echo $(RUN_FASTQC) -version  >> versions.log
	$(RUN_FASTQC) -version  >> versions.log  2>&1
	echo rpm -q fastqc >> versions.log
	rpm -q fastqc >> versions.log 2>&1
	echo "flexbar"  >> versions.log
	echo "-------"  >> versions.log
	echo flexbar -version >> versions.log
	flexbar -version >> versions.log  2>&1
	echo rpm -q flexbar >> versions.log
	rpm -q flexbar >> versions.log 2>&1


######################################################################
# top level targets
######################################################################
.PHONY : %.all 
%.all: %.processed 
	echo making $@

%.processed: %.processed_in_progress
	# check it all looks right and then 
	mv $< $@

%.processed_in_progress: %.processed_in_progress/bcl2fastq
	echo making $@

%.processed_in_progress/bcl2fastq: %.processed_in_progress/bcl2fastq_in_progress
	# check it all looks right and then
	mv $< $@

%.processed_in_progress/bcl2fastq_in_progress:
	mkdir -p  $@
	touch $@
	#$(RUN_BCL2FASTQ) -d 8 -p 8  --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions --ignore-missing-controls --auto-set-to-zero-barcode-mismatches --find-adapters-with-sliding-window --adapter-stringency 0.9 --mask-short-adapter-reads 35 --minimum-trimmed-read-length 35 -R $(hiseq_root)/$(*F)  --sample-sheet $(hiseq_root)/$(*F)/SampleSheet.csv -o $@  -i $(hiseq_root)/$(*F)/Data/Intensities/BaseCalls  > $*_bcl2fastq.log 2>&1
	ulimit -n 4000; $(RUN_BCL2FASTQ) -p 8  --ignore-missing-bcls --ignore-missing-filter --ignore-missing-positions --ignore-missing-controls --auto-set-to-zero-barcode-mismatches --find-adapters-with-sliding-window --adapter-stringency 0.9 --mask-short-adapter-reads 35 --minimum-trimmed-read-length 35 -R $(hiseq_root)/$(*F)  --sample-sheet $(hiseq_root)/$(*F)/SampleSheet.csv -o $@  -i $(hiseq_root)/$(*F)/Data/Intensities/BaseCalls  > $*_bcl2fastq.log 2>&1
	find $@ -name "*.fastq.gz" -type f -exec chmod g-w,o-w {} \;



##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS:  %.processed %.processed_in_progress %.processed_in_progress/bcl2fastq %.processed_in_progress/bcl2fastq_in_progress

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

