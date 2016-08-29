#Contributing to DECONVQC

Contributions are welcome. The following is a brief set of guidelines for contributing to DECONVQC 

#Which GBS project to contribute to?  
There are a number of community projects related to GBS. DECONVQC is limited in scope, focusing mainly 
on immediate upstream Q/C and sequence delivery, rather than custom downstream analyses. If you are mainly 
interested in contributing to a general purpose GBS research tool, we would encourage you to consider 
contributing to one of the projects focused on that goal such as the BBS project coordinated by the 
Elshire group and others. However contributions to the basic DECONVQC goal of high quality sequence 
delivery are always welcome! 

#Code of Conduct
See CODE\_OF\_CONDUCT.md 

#Contribution areas: 
#Database 
##Schema
#Keyfile and run data management 
#Generic Sequence Q/C (i.e. not GBS-specific)
##Fastqc
##Alignment of sample against references
##Contamination check - alignment of random sample of reads against nt 
##GBS Q/C 
###Tassel
###KGD
###k-mer analysis
#Overall workflow 
#Presenting Results to Users
#Project Lifecycle 
#Utilities
#Documentation


#How Can I Contribute?
In many cases contributions should be directed to the relevant project that provides the 
utility we are re-using - examples include  

* Tassel
* KGD
* prbdf
* brdf database schema 


#Reporting Bugs

#Suggesting Enhancements
The devops approach in this project is somewhat conservative, in the sense of trying to minimise 
dependencies, to ensure that it is easy to run the process in the kind of standard real-time environment 
often associated with sequencing machines (i.e. sequencing machine output must be processed 
reliably within a day or two of the run completing; any faults will require weekend callout of 
staff). So, while there are many specialist workflow systems that have advantages over makefiles, and 
alternative languages and libraries that may have some performance and other advantages over the languages 
and libraries used here, in this early stage we are consolidating essentially on makefiles, bash, R and python. In 
suggesting enhancements, bear in mind the real-time production environment in which your enhancement 
will be required to run, and that requirements for a highly customised dependency stack will probably 
not be able to be met.

#Pull Requests

#Style guides
##Git Commit Messages
##Bash Style guide
##Python Style guide
##R Style guide
##Documentation Style guide


#Additional Notes
##Issue and Pull Request Labels

