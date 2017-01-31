#
# gbs_hiseq processing pipeline version 1.0 
#***************************************************************************************
# changes 
# 1.0 initial version - UNEAK
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
GET_READS_TAGS_PER_SAMPLE=$(GBS_BIN)/get_reads_tags_per_sample.py

# variables for tardis and other apps
machine=hiseq
parameters_file=


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
.PHONY : %.qc  
%.qc: $(analysis_targets)  
	echo making $@

%.processed_sample/uneak/blast_analysis/sample_blast_summary.jpg: %.processed_sample/uneak/blast_analysis_in_progress/sample_blast_summary.jpg
	# check it looks OK then
	mv $*.processed_sample/uneak/blast_analysis_in_progress $*.processed_sample/uneak/blast_analysis


%.processed_sample/uneak/kmer_analysis/zipfian_distances.jpg: %.processed_sample/uneak/kmer_analysis_in_progress/zipfian_distances.jpg 
	# check it looks OK then
	mv $*.processed_sample/uneak/kmer_analysis_in_progress $*.processed_sample/uneak/kmer_analysis


%.processed_sample/uneak/blast_analysis_in_progress/sample_blast_summary.jpg :  %.processed_sample/uneak/KGD
	mkdir -p $(dir $@)
	cd $(dir $@); $(GBS_BIN)/utils/blast_analyse_samples.sh -D $</../tagCounts/ -O $(dir $@) 1>$(dir $@)/blast.stdout 2>$(dir $@)/blast.stderr
	cd $(dir $@);$(GBS_BIN)/utils/blast_analyse_samples.sh -T summarise -O $(dir $@) 1>$(dir $@)/summary.stdout 2>$(dir $@)/summary.stderr
	/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla $(GBS_BIN)/blast_summary_heatmap.r datafolder=$(dir $@)

%.processed_sample/uneak/kmer_analysis_in_progress/zipfian_distances.jpg:  %.processed_sample/uneak/KGD 
	mkdir -p $(dir $@)
	cd $(dir $@); $(GBS_BIN)/kmer_entropy.py -b $(dir $@) -t zipfian -k 6 -p 1 -o $(dir $@)/kmer_summary.txt  -x $(GBS_BIN)/cat_tag_count.sh $</../tagCounts/*.cnt 1>$(dir $@)/zipfian.stdout 2>$(dir $@)/zipfian.stderr
	$(dir $@); $(GBS_BIN)/kmer_entropy.py -b $(dir $@) -t frequency -k 6 -p 1 -o $(dir $@)/kmer_frequency.txt  -x $(GBS_BIN)/cat_tag_count.sh $</../tagCounts/*.cnt 1>$(dir $@)/frequency.stdout 2>$(dir $@)/frequency.stderr
	/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla  $(GBS_BIN)/kmer_plots_gbs.r datafolder=$(dir $@) 1>$(dir $@)/plots.stdout 2>$(dir $@)/plots.stderr


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS:  %.gbs  %.processed_sample %.processed_sample/uneak/kmer_analysis_in_progress/zipfian_distances.jpg  %.processed_sample/uneak/kmer_analysis/zipfian_distances.jpg %.processed_sample/uneak/KGD %.processed_sample/uneak/blast_analysis_in_progress/sample_blast_summary.jpg %.processed_sample/uneak/blast_analysis/sample_blast_summary.jpg

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

