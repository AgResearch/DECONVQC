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
RUN_BCL2FASTQ=/usr/lib64/bcl2fastq-1.8.4/bin/configureBclToFastq.pl
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
.PHONY : %.all  %.uneak
%.all: %.gbs 
	echo making $@
%.uneak: %.gbs 
	echo making $@

%.gbs: %.gbs_in_progress
	# check it all looks right and then 
	# make the key file
	# set up any required soft links to sequences to satisfy tassel 
	mv $< $@

%.gbs_in_progress: $(processed_samples)
	echo making $@

%.processed_sample: %.sample_in_progress
	# check it all looks right and then
	mv $< $@

%.sample_in_progress: %.sample_in_progress/uneak
	# check it looks ok
	echo "checking $@"

%.sample_in_progress/uneak: %.sample_in_progress/uneak_in_progress
	# check it all looks right and then
	./check_uneak_run.sh $< global
	mv $< $@

%.sample_in_progress/uneak_in_progress:  %.sample_in_progress/uneak_in_progress/kmer_analysis/zipfian_distances.jpg   %.sample_in_progress/uneak_in_progress/blast_analysis/sample_blast_summary.jpg
	# check it looks ok
	echo "checking $@"

%.sample_in_progress/uneak_in_progress/blast_analysis/sample_blast_summary.jpg:  %.sample_in_progress/uneak_in_progress/KGD
	mkdir -p $(dir $@)
	$(GBS_BIN)/utils/blast_analyse_samples.sh -D $</../tagCounts/ -O $(dir $@)
	$(GBS_BIN)/utils/blast_analyse_samples.sh -T summarise -O $(dir $@)
	/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla $(GBS_BIN)/blast_summary_heatmap.r datafolder=$(dir $@)

%.sample_in_progress/uneak_in_progress/kmer_analysis/zipfian_distances.jpg:  %.sample_in_progress/uneak_in_progress/KGD
	mkdir -p $(dir $@)
	$(GBS_BIN)/kmer_entropy.py -b $(dir $@) -t zipfian -k 6 -p 1 -o $(dir $@)/kmer_summary.txt  -x $(GBS_BIN)/cat_tag_count.sh $</../tagCounts/*.cnt
	$(GBS_BIN)/kmer_entropy.py -b $(dir $@) -t frequency -k 6 -p 1 -o $(dir $@)/kmer_frequency.txt  -x $(GBS_BIN)/cat_tag_count.sh $</../tagCounts/*.cnt
	/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla  $(GBS_BIN)/kmer_plots_gbs.r datafolder=$(dir $@)

%.sample_in_progress/uneak_in_progress/KGD: %.sample_in_progress/uneak_in_progress/hapMap
	mkdir -p $@
	$(GBS_BIN)/run_kgd.sh $@ 

%.sample_in_progress/uneak_in_progress/hapMap: %.sample_in_progress/uneak_in_progress/mapInfo
	mkdir -p $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UMapInfoToHapMapPlugin -w ./ -mnMAF 0.03 -mxMAF 0.5 -mnC 0.1 -endPlugin -runfork1 > UMapInfoToHapMap.out 2> UMapInfoToHapMap.se

%.sample_in_progress/uneak_in_progress/mapInfo: %.sample_in_progress/uneak_in_progress/tagsByTaxa
	mkdir -p $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UTBTToMapInfoPlugin -w ./ -endPlugin -runfork1 > UTBTToMapInfo.out 2> UTBTToMapInfo.se 

%.sample_in_progress/uneak_in_progress/tagsByTaxa: %.sample_in_progress/uneak_in_progress/tagPair
	mkdir -p $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UTagPairToTBTPlugin -w ./ -endPlugin -runfork1 > UTagPairToTBT.out 2> UTagPairToTBT.se 

%.sample_in_progress/uneak_in_progress/tagPair: %.sample_in_progress/uneak_in_progress/mergedTagCounts
	mkdir -p $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UTagCountToTagPairPlugin -w ./ -e 0.03 -endPlugin -runfork1 > UTagCountToTagPair.out 2> UTagCountToTagPair.se 

%.sample_in_progress/uneak_in_progress/mergedTagCounts: %.sample_in_progress/uneak_in_progress/tagCounts
	mkdir -p $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UMergeTaxaTagCountPlugin -w ./ -m 600000000 -x 100000000 -c 5 -endPlugin -runfork1 > UMergeTaxaTagCount.out 2> UMergeTaxaTagCount.se 

%.sample_in_progress/uneak_in_progress/tagCounts: %.sample_in_progress/uneak_in_progress/Illumina  %.sample_in_progress/uneak_in_progress/key
	mkdir -p $@
	enzyme=`$(GBS_BIN)/get_processing_parameters.py --parameter_file $(parameters_file) --parameter_name enzymes  --sample $(notdir $*)`; echo "making UFastqToTagCount using enzyme $$enzyme"
	cd $@/..; enzyme=`$(GBS_BIN)/get_processing_parameters.py --parameter_file $(parameters_file) --parameter_name enzymes  --sample $(notdir $*)`; run_pipeline.pl -Xms512m -Xmx5g -fork1 -UFastqToTagCountPlugin -w ./ -c 1 -e $$enzyme -s 400000000 -endPlugin -runfork1 > UFastqToTagCount.out 2> UFastqToTagCount.se
	#cd $@/..; run_pipeline.pl -Xms512m -Xmx5g -fork1 -UFastqToTagCountPlugin -w ./ -c 1 -e PstI -s 300000000 -endPlugin -runfork1 > UFastqToTagCount.out 2> UFastqToTagCount.se
	#cd $@/..; run_pipeline.pl -Xms512m -Xmx5g -fork1 -UFastqToTagCountPlugin -w ./ -c 1 -e ApeKI -s 300000000 -endPlugin -runfork1 > UFastqToTagCount.out 2> UFastqToTagCount.se
	cd $@/..; $(GBS_BIN)/get_reads_tags_per_sample.py  

%.sample_in_progress/uneak_in_progress/Illumina: 
	mkdir -p $@
	$(GBS_BIN)/link_fastq_files.sh $@

%.sample_in_progress/uneak_in_progress/key: 
	mkdir -p $@
	$(GBS_BIN)/link_key_files.sh $@


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS:  %.gbs %.gbs_in_progress %.processed_sample %.sample_in_progress %.sample_in_progress/uneak %.sample_in_progress/uneak_in_progress %.sample_in_progress/uneak_in_progress/kmer_analysis %.sample_in_progress/uneak_in_progress/blast_analysis %.sample_in_progress/uneak_in_progress/KGD %.sample_in_progress/uneak_in_progress/hapMap %.sample_in_progress/uneak_in_progress/mapInfo %.sample_in_progress/uneak_in_progress/tagsByTaxa %.sample_in_progress/uneak_in_progress/tagPair %.sample_in_progress/uneak_in_progress/mergedTagCounts %.sample_in_progress/uneak_in_progress/tagCounts %.sample_in_progress/uneak_in_progress/Illumina %.sample_in_progress/uneak_in_progress/key

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

