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
RUN_KMER_ANALYSIS=$(GBS_BIN)/run_kmer_analysis.sh

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
%.all: %.processed/mapping_preview  %.processed/fastqc_analysis  %.processed/kmer_analysis
	echo making $@

%.processed/kmer_analysis: %.processed/kmer_analysis_in_progress
	# check it all looks right and then
	# temporarily commented out while debugging
	mv $< $@

%.processed/mapping_preview: %.processed/mapping_preview_in_progress
	# check it all looks right and then
	# temporarily commented out while debugging
	mv $< $@

%.processed/kmer_analysis_in_progress: %.processed/taxonomy_analysis
	mkdir -p $@
	touch $@
	cd $@; $(RUN_KMER_ANALYSIS) $(run) $@ > $@/run_kmer_analysis.log 2>&1 

%.processed/mapping_preview_in_progress: %.processed/taxonomy_analysis
	mkdir -p $@
	touch $@
	#$(RUN_MAPPING_PREVIEW) $(notdir $(*F)) $(machine)
	cd $@; $(RUN_MAPPING_PREVIEW) $(run) $@ > $@/run_mapping_preview.log 2>&1

%.processed/taxonomy_analysis: %.processed/taxonomy_analysis_in_progress
	# check it all looks right and then
	mv $< $@

# the second pattern is used for running this later on
%.processed/taxonomy_analysis_in_progress: %.processed/bcl2fastq 
	mkdir -p $@
	touch $@
	#$(RUN_CONTAMINATION_CHECK) $(notdir $(*F)) $(TARDIS_chunksize) $(SAMPLE_RATE) 
	#cd $@; $(RUN_CONTAMINATION_CHECK) $(run) $@ $($(machine)) 
	cd $@; $(RUN_CONTAMINATION_CHECK) $(run) $@ > $@/run_contamination_check.log 2>&1

%.processed/fastqc_analysis: %.processed/fastqc_analysis_in_progress
	# check it all looks right and then
	mv $< $@

%.processed/fastqc_analysis_in_progress: %.processed/bcl2fastq
	mkdir -p $@ 
	touch $@
	cd $@; find $</*/ -name "*.fastq.gz" > $@/fastq.list
	cd $@; $(RUN_FASTQC) -t 8 -o $@ `cat $@/fastq.list`



##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS:  %.processed %.processed/taxonomy_analysis %.processed/taxonomy_analysis_in_progress %.processed/fastqc_analysis %.processed/fastqc_analysis_in_progress %.processed/bcl2fastq %.processed/mapping_preview %.processed/mapping_preview_in_progress

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

