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
run_temp=


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
.PHONY : %.all  %.uneak %.blast_analysis
%.all: %.gbs 
	echo making $@
%.uneak: %.gbs 
	echo making $@

%.gbs: %.gbs_in_progress
	# check it all looks right and then 
	# make the key file
	# set up any required soft links to sequences to satisfy tassel 
	mv $< $@
	touch $@

%.blast_analysis: $(blast_analyses) 
	echo making $@

%.gbs_in_progress: $(processed_samples)
	echo making $@

%.processed_sample: %.sample_in_progress
	# check it all looks right and then
	mv $< $@
	touch $@

%.sample_in_progress: %.sample_in_progress/uneak
	# check it looks ok
	echo "checking $@"

%.sample_in_progress/uneak: %.sample_in_progress/uneak_in_progress
	# check it all looks right and then
	./check_uneak_run.sh $< global
	mv $< $@
	touch $@

.SECONDEXPANSION:
%.sample_in_progress/uneak_in_progress:  $$(addprefix $$@/, $$(notdir $$(addsuffix .enzyme , $$(wildcard $(run_temp)/$$(*F)/uneak_enzymes/* ))))
	# running merge of enzyme-specific results
	echo "running merge of $+ to obtain $@"
	$(GBS_BIN)/merge_enzymes.sh  $@ $+


%.enzyme:  %.enzyme/KGD
#	# check it looks ok
	echo "checking $@"


# The target here supports running the blast analysis later on as a seperate run after the main gbs analysis is finished
%.processed_sample/uneak/blast_analysis/sample_blast_summary.jpg:  
	mkdir -p $(@D)
	$(GBS_BIN)/utils/blast_analyse_samples.sh -D $(@D)/../tagCounts/ -O $(@D) 1>$(@D)/blast.stdout 2>$(@D)/blast.stderr
	$(GBS_BIN)/utils/blast_analyse_samples.sh -T summarise -O $(@D) 1>$(@D)/summary.stdout 2>$(@D)/summary.stderr
	/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla $(GBS_BIN)/blast_summary_heatmap.r datafolder=$(@D)

# The target here supports running the kmer analysis later on as a seperate run after the main gbs analysis is finished
%.processed_sample/uneak/kmer_analysis/zipfian_distances.jpg:  
	mkdir -p $(@D)
	$(GBS_BIN)/kmer_entropy.py -b $(@D) -t zipfian -k 6 -p 1 -o $(@D)/kmer_summary.txt  -x $(GBS_BIN)/cat_tag_count.sh $(@D)/../tagCounts/*.cnt 1>$(@D)/zipfian.stdout 2>$(@D)/zipfian.stderr
	$(GBS_BIN)/kmer_entropy.py -b $(@D) -t frequency -k 6 -p 1 -o $(@D)/kmer_frequency.txt  -x $(GBS_BIN)/cat_tag_count.sh $(@D)/../tagCounts/*.cnt 1>$(@D)/frequency.stdout 2>$(@D)/frequency.stderr
	/dataset/bioinformatics_dev/active/R3.3/R-3.3.0/bin/Rscript --vanilla  $(GBS_BIN)/kmer_plots_gbs.r datafolder=$(@D) 1>$(@D)/plots.stdout 2>$(@D)/plots.stderr

%.enzyme/KGD: %.enzyme/hapMap
	mkdir -p $@
	touch $@
	$(GBS_BIN)/run_kgd.sh $@ 

%.enzyme/hapMap: %.enzyme/mapInfo
	mkdir -p $@
	touch $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UMapInfoToHapMapPlugin -w ./ -mnMAF 0.03 -mxMAF 0.5 -mnC 0.1 -endPlugin -runfork1 > UMapInfoToHapMap.out 2> UMapInfoToHapMap.se

%.enzyme/mapInfo: %.enzyme/tagsByTaxa
	mkdir -p $@
	touch $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UTBTToMapInfoPlugin -w ./ -endPlugin -runfork1 > UTBTToMapInfo.out 2> UTBTToMapInfo.se 

%.enzyme/tagsByTaxa: %.enzyme/tagPair

	mkdir -p $@
	touch $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UTagPairToTBTPlugin -w ./ -endPlugin -runfork1 > UTagPairToTBT.out 2> UTagPairToTBT.se 

%.enzyme/tagPair: %.enzyme/mergedTagCounts
	mkdir -p $@
	touch $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UTagCountToTagPairPlugin -w ./ -e 0.03 -endPlugin -runfork1 > UTagCountToTagPair.out 2> UTagCountToTagPair.se 

%.enzyme/mergedTagCounts: %.enzyme/tagCounts
	mkdir -p $@
	touch $@
	cd $@/..;run_pipeline.pl -Xms512m -Xmx500g -fork1 -UMergeTaxaTagCountPlugin -w ./ -m 600000000 -x 100000000 -c 5 -endPlugin -runfork1 > UMergeTaxaTagCount.out 2> UMergeTaxaTagCount.se 

%.enzyme/tagCounts: %.enzyme/Illumina  %.enzyme/key
	mkdir -p $@
	touch $@
	#enzyme=`$(GBS_BIN)/get_processing_parameters.py --parameter_file $(parameters_file) --parameter_name enzymes  --sample $(notdir $*)`; echo "making UFastqToTagCount using enzyme $$enzyme"
	#cd $@/..; enzyme=`$(GBS_BIN)/get_processing_parameters.py --parameter_file $(parameters_file) --parameter_name enzymes  --sample $(notdir $*)`; run_pipeline.pl -Xms512m -Xmx5g -fork1 -UFastqToTagCountPlugin -w ./ -c 1 -e $$enzyme -s 400000000 -endPlugin -runfork1 > UFastqToTagCount.out 2> UFastqToTagCount.se
	echo "making UFastqToTagCount using enzyme $(*F)"
	cd $@/..; run_pipeline.pl -Xms512m -Xmx5g -fork1 -UFastqToTagCountPlugin -w ./ -c 1 -e $(*F) -s 400000000 -endPlugin -runfork1 > UFastqToTagCount.out 2> UFastqToTagCount.se
	cd $@/..; $(GBS_BIN)/get_reads_tags_per_sample.py  

%.enzyme/Illumina: 
	mkdir -p $@
	touch $@
	$(GBS_BIN)/link_fastq_files.sh $@

%.enzyme/key: 
	mkdir -p $@
	touch $@
	$(GBS_BIN)/link_key_files.sh $@


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS:  %.gbs %.gbs_in_progress %.processed_sample %.sample_in_progress %.sample_in_progress/uneak %.sample_in_progress/uneak_in_progress %.enzyme/kmer_analysis %.enzyme/blast_analysis %.processed_sample/uneak/blast_analysis %.enzyme/KGD %.enzyme/hapMap %.enzyme/mapInfo %.enzyme/tagsByTaxa %.enzyme/tagPair %.enzyme/mergedTagCounts %.enzyme/tagCounts %.enzyme/Illumina %.enzyme/key %.enzyme/blast_analysis/sample_blast_summary.jpg %.processed_sample/uneak/blast_analysis/sample_blast_summary.jpg %.enzyme/kmer_analysis/zipfian_distances.jpg

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

