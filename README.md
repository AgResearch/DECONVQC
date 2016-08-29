This repository contains scripts used to process and manage output sequence data and metadata related to Illumina hiseq and miseq machines, including running a number of GBS-specific Q/C steps for predominately GBS-related sequencing output. This project is focussed on immediate upstream Q/C and sequence delivery, rather than custom downstream analyses.

Refer to DECONVQC.docx for more details

This resource contributes to and is partly supported by the MBIE programme "Genomics for Production & Security in a Biological Economy"

Below is a summary of the contents of the repository


#Database 
##Schema

* setup.psql
* setup\_quick\_reports.psql


#Keyfile and run data management 
* deleteKeyfile.psql    
* get\_keyfilename.psql      
* updateFastQLocationInKeyFile.psql
* checkKeyFiles.psql                
* extractKeyfile5.psql  
* extract\_sample\_species.psql  
* extractKeyfile.psql   
* get\_fastq\_link.psql  
* addRun.sh          
* get\_enzyme\_count\_from\_database.sh  
* get\_lane\_from\_database.sh  
* is\_keyfile\_in\_database.sh  
* deleteKeyfile.sh   
* get\_enzyme\_from\_database.sh        
* importKeyfile.sh           
* is\_run\_in\_database.sh      
* updateFastqLocations.sh
* extractKeyfile.sh  
* get\_flowcellid\_from\_database.sh    
* importOrUpdateKeyfile.sh   
* listDBKeyfile.sh
* sanitiseKeyFile.py

       
#Generic Sequence Q/C (i.e. not GBS-specific)
##Fastqc
##Alignment of sample against references
* run\_mapping\_preview.sh  

##Contamination check - alkignment of random sample of reads against nt 
* run\_sample\_contamination\_checks.sh
* summarise\_global\_hiseq\_taxonomy.sh
* summarise\_global\_hiseq\_taxonomy.py
* taxonomy\_clustering.r

##GBS Q/C 

###Tassel
* link\_key\_files.sh
* summarise\_global\_hiseq\_reads\_tags\_cv.sh
* summarise\_read\_and\_tag\_counts.py
* summarise\_hiseq\_taxonomy.py
* get\_reads\_tags\_per\_sample.py
* tags\_plots.r

###KGD
* batch\_kgd.sh 
* run\_kgd.sh
* GBS-Chip-Gmatrix.R  
* run\_kgd.R

###k-mer analysis
* kmer\_entropy.py  
* kmer\_plots\_gbs.r  
	
#Overall workflow 
* process\_hiseq1.0.sh     
* gbs\_hiseq1.0.sh      
* archive\_hiseq1.0.sh  
* process\_hiseq1.0.mk     
* gbs\_hiseq1.0.mk      
* archive\_hiseq1.0.mk  
* get\_processing\_parameters.py  
* species\_config.txt

#Presenting Results to Users
* extract\_peacock.psql   
* make\_peacock\_plots.sh
* make\_peacock\_plots.py  
* make\_run\_plots.py  

#Project Lifecycle 
* clean\_hiseq\_run.sh
* fix\_archived\_run\_fastq\_links.sh

#Utilities
* cat\_tag\_count.sh   
* tags\_to\_fasta.py
* prbdf.py 

#Documentation
* DECONVQC.docx       

 


