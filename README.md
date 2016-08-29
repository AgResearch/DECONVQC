This repository contains scripts used to process and manage output sequence data and metadata related to Illumina hiseq and miseq machines, including running a number of GBS-specific Q/C steps for predominately GBS-related sequencing output. This project is focussed on immediate upstream Q/C and sequence delivery, rather than custom downstream analyses.

Refer to DECONVQC.docx for more details

This resource contributes to and is partly supported by the MBIE programme "Genomics for Production & Security in a Biological Economy"

Below is a summary of the contents of the repository


#Database 
##Schema
##Scripts
##Stored Procedures 

#Analyses
##Generic Sequence Q/C
####Fastqc
####Alignment of sample against references
####Contamination check processing (blast, summaries, plots)
###GBS Q/C 
####Tassel
####KGD
####Kmer analysis
####Yield summaries, variance etc. 
	
##Overall workflow 
###Logging
###Makefiles









