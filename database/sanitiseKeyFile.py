#!/bin/env python

# some keyfiles are padded with extra empty columns at the right hand end , this upsets the database importer
# to use; some have empty rows at the end - ditto. To use , e.g. 
# cp /dataset/hiseq/active/key-files/SQ2530.txt /dataset/hiseq/active/key-files/SQ2530.txt.bu2
# cat /dataset/hiseq/active/key-files/SQ2530.txt.bu2 | ./sanitiseKeyFile.py > /dataset/hiseq/active/key-files/SQ2530.txt
# cat /dataset/hiseq/active/key-files/SQ2530.txt | ./sanitiseKeyFile.py > junk

import sys
import re
import string

rowcount = 1
numcol = None
DEBUG=False
for record in sys.stdin:
   if rowcount == 1 :
      numcol = len(re.split("\t", record.strip()))
      if DEBUG:
         print "****", rowcount, numcol,re.split("\t", record.strip())
   else:
      record_numcol = len(re.split("\t", record.strip()))
      if DEBUG:
         print "****", rowcount, record_numcol,numcol,re.split("\t", record.strip())
      if len(record.strip()) == 0:
         continue
      if numcol - record_numcol in (1,2,3):   # allow limited padding
         # pad with one or more empty strings - sometimes the fastq column is missing and sometimes also the bifo column
         print string.join(re.split("\t", record.strip())[0:numcol] + [""]*(numcol-record_numcol), "\t")
         if DEBUG:
            print "---->", len(re.split("\t", string.join(re.split("\t", record.strip())[0:numcol] + [" "], "\t"))),re.split("\t", string.join(re.split("\t", record.strip())[0:numcol] + [" "], "\t"))
      elif numcol - record_numcol == 0:
         print string.join(re.split("\t", record.strip())[0:numcol], "\t")
      elif numcol != record_numcol:
         raise Exception("error reading keyfile at record %d - expected %d columns but see %d"%(rowcount, numcol, record_numcol))
      else:
         raise Exception("error reading keyfile at record %d - fell through the logic"%rowcount)
   rowcount += 1

