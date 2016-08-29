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
#
# ******************************************************************************************
# other variables (not project specific)
# ******************************************************************************************
RUN_TARDIS=tardis.py
RUN_FASTQC=fastqc
RUN_BCL2FASTQ=/usr/lib64/bcl2fastq-1.8.4/bin/configureBclToFastq.pl
RUN_CONTAMINATION_CHECK=/dataset/hiseq/active/bin/hiseq_pipeline/run_sample_contamination_checks.sh
RUN_MAPPING_PREVIEW=/dataset/hiseq/active/bin/hiseq_pipeline/run_mapping_preview.sh

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
	egrep "configureBclToFastq" $*.log >> $*.logprecis
	egrep "^cd " $*.log >> $*.logprecis
	egrep "^nohup make " $*.log >> $*.logprecis
	egrep "^find " $*.log >> $*.logprecis

	echo "fastqc" >> $*.logprecis
	echo "------" >> $*.logprecis
	egrep "^$(RUN_FASTQC)" $*.log  >> $*.logprecis

	echo "contamination check" >> $*.logprecis
	echo "-----" >> $*.logprecis
	egrep "run_sample_contamination_checks.sh" $*.log  >> $*.logprecis

	echo "mapping preview" >> $*.logprecis
	echo "-----" >> $*.logprecis
	egrep "run_mapping_preview.sh" $*.log  >> $*.logprecis

	echo "mkdir" >> $*.logprecis
	echo "-----" >> $*.logprecis
	egrep "mkdir" $*.log >> $*.logprecis

	echo "file linking" >> $*.logprecis
	echo "------------" >> $*.logprecis
	egrep "^ln -s" $*.log >> $*.logprecis

	echo "move in_progress to done" >> $*.logprecis
	echo "------------------------" >> $*.logprecis
	egrep "^mv " $*.log | grep "in_progress" >> $*.logprecis

	echo "waiting" >> $*.logprecis
	echo "-------" >> $*.logprecis
	egrep "^while >> $*.logprecis



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

%.archived: %.processed
	# commands to move the results to archive


%.processed: %.processed_in_progress
	# check it all looks right and then 
	# make the key file
	# set up any required soft links to sequences to satisfy tassel 
	mv $< $@

%.processed_in_progress: %.processed_in_progress/mapping_preview  %.processed_in_progress/fastqc_analysis
	echo making $@

%.processed_in_progress/mapping_preview: %.processed_in_progress/mapping_preview_in_progress
	# check it all looks right and then
	# temporarily commented out while debugging
	mv $< $@

%.processed_in_progress/mapping_preview_in_progress: %.processed_in_progress/taxonomy_analysis
	if [ ! -d $@ ]; then mkdir $@ ; fi
	$(RUN_MAPPING_PREVIEW) $(notdir $(*F)) $(machine)

%.processed_in_progress/taxonomy_analysis: %.processed_in_progress/taxonomy_analysis_in_progress
	# check it all looks right and then
	mv $< $@

%.processed_in_progress/taxonomy_analysis_in_progress: %.processed_in_progress/bcl2fastq 
	echo making $@
	if [ ! -d $@ ]; then mkdir $@ ; fi
	#$(RUN_CONTAMINATION_CHECK) $(notdir $(*F)) $(TARDIS_chunksize) $(SAMPLE_RATE) 
	$(RUN_CONTAMINATION_CHECK) $(notdir $(*F)) $(machine) $($(machine)) 

%.processed_in_progress/fastqc_analysis: %.processed_in_progress/fastqc_analysis_in_progress
	# check it all looks right and then
	mv $< $@

%.processed_in_progress/fastqc_analysis_in_progress: %.processed_in_progress/bcl2fastq
	if [ ! -d $@ ]; then mkdir $@ ; fi
	$(RUN_FASTQC) -t 8 -o $@ `cat $</fastq.list`

%.processed_in_progress/bcl2fastq: %.processed_in_progress/bcl2fastq_in_progress
	# check it all looks right and then
	find $< -name "*.fastq.gz" | sed 's/bcl2fastq_in_progress/bcl2fastq/g' - > $</fastq.list
	mv $< $@

%.processed_in_progress/bcl2fastq_in_progress:
	if [ ! -d $*.processed_in_progress ]; then mkdir $*.processed_in_progress  ; fi
	if [ ! -d $@ ]; then mkdir $@ ; fi
	$(RUN_BCL2FASTQ) --input-dir $(hiseq_root)/$(*F)/Data/Intensities/BaseCalls --force --output-dir $@ --sample-sheet $(hiseq_root)/$(*F)/SampleSheet.csv --no-eamss --mismatches 0 --adapter-sequence $(adapters_file1) --adapter-sequence $(adapters_file2) --fastq-cluster-count 0 > $*_configureBclToFastq.log 2>&1
	cd $@ && nohup make -j 24 > $*_bcl2fastq.log 2>&1


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS:  %.processed %.processed_in_progress %.processed_in_progress/taxonomy_analysis %.processed_in_progress/taxonomy_analysis_in_progress %.processed_in_progress/fastqc_analysis %.processed_in_progress/fastqc_analysis_in_progress %.processed_in_progress/bcl2fastq %.processed_in_progress/bcl2fastq %.processed_in_progress/mapping_preview %.processed_in_progress/mapping_preview_in_progress

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 
