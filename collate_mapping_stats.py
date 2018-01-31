#!/bin/env python 
import sys
import re
import os

bam_stats_files=sys.argv[1:]
stats_dict={}

for filename in bam_stats_files:
   # e.g. Repro.sample.fastq.trimmed_vs_umd_3_1_reference_1000_bull_genomes.fa
   # containing e.g.
   #Mapped reads:      260087	(70.3575%)
   #Forward strand:    239494	(64.7868%)
   #Reverse strand:    130171	(35.2132%)
   sample = re.split("\.", os.path.basename(filename))[0]
   map_stats = [(0,0), (0,0), (0,0)] # will contain all, forward , reverse
                                  # and for each , (count, percent)
   
   with open(filename,"r") as f:     
      for record in f:
         tokens = re.split("\s+", record.strip())
         #print tokens
         if len(tokens) > 0:
            if tokens[0] == "Mapped":
               map_stats[0] = (float(re.search("^\((\S+)\%\)$", tokens[3]).groups()[0])/100.0, int(tokens[2]))
            elif tokens[0] == "Forward":
               map_stats[1] = (float(re.search("^\((\S+)\%\)$", tokens[3]).groups()[0])/100.0, int(tokens[2]))
            elif tokens[0] == "Reverse":
               map_stats[2] = (float(re.search("^\((\S+)\%\)$", tokens[3]).groups()[0])/100.0, int(tokens[2]))

   stats_dict[sample] = map_stats

print "\t".join(("sample", "map_pct", "map_std"))
for sample in stats_dict:
   out_rec = [sample,"0","0"]

   # mapped stats
   (p,n) = stats_dict[sample][0]
   if p > 0:
      n = n/p

   q = 1-p
   if n>0:
      stddev = (p * q / n ) ** .5
   out_rec[1] = str(p*100.0)
   out_rec[2] = str(stddev*100.0)
   print "\t".join(out_rec)
                               
                               

   

               
                    
            
                    
                    
         
        
                    
