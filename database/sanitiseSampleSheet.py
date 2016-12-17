#!/bin/env python

notes = """

agrbrdf=> \d samplesheet_temp
          Table "public.samplesheet_temp"
    Column     |          Type          | Modifiers
---------------+------------------------+-----------
 fcid          | character varying(32)  |
 lane          | integer                |
 sampleid      | character varying(32)  |
 sampleref     | character varying(32)  |
 sampleindex   | integer                |
 description   | character varying(256) |
 control       | character varying(32)  |
 recipe        | integer                |
 operator      | character varying(256) |
 sampleproject | character varying(256) |


which we populate with

\copy samplesheet_temp from /tmp/161205_D00390_0274_AC9KW9ANXX.txt with  CSV HEADER

from e.g. 

[Header],,,,,,,,,,
IEMFileVersion,4,,,,,,,,,
Date,2/12/2016,,,,,,,,,
Workflow,GenerateFASTQ,,,,,,,,,
Application,HiSeq FASTQ Only,,,,,,,,,
Assay,TruSeq HT,,,,,,,,,
Description,,,,,,,,,,
Chemistry,Amplicon,,,,,,,,,
,,,,,,,,,,
[Reads],,,,,,,,,,
101,,,,,,,,,,
,,,,,,,,,,
[Settings],,,,,,,,,,
ReverseComplement,0,,,,,,,,,
Adapter,AGATCGGAAGAGCACACGTCTGAACTCCAGTCA,,,,,,,,,
AdapterRead2,AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT,,,,,,,,,
,,,,,,,,,,
[Data],,,,,,,,,,
Lane,Sample_ID,Sample_Name,Sample_Plate,Sample_Well,I7_Index_ID,index,I5_Index_ID,index2,Sample_Project,Description
1,SQ0279,SQ0279,,,,,,,Deer,Deer_SQ0279_PstI
2,SQ0280,SQ0280,,,,,,,Deer,Deer_SQ0280_PstI
3,SQ0281,SQ0281,,,,,,,Robin,Robin_SQ0281_ApeKI-MspI
4,SQ0282,SQ0282,,,,,,,Goat,Goat_SQ0282_PstI
5,SQ0283,SQ0283,,,,,,,Goat,Goat_SQ0283_PstI
6,SQ0284_SS_Intron_1,SQ0284_SS_Intron_1,,1,AD002,CGATGT,IDX01,GAAATG,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_Intron_2,SQ0284_SS_Intron_2,,2,AD002,CGATGT,IDX02,GGACCT,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_Exon2_1,SQ0284_SS_Exon2_1,,3,AD007,CAGATC,IDX03,CGAGGC,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_Exon2_2,SQ0284_SS_Exon2_2,,4,AD007,CAGATC,IDX04,TCTTCT,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_Exon3,SQ0284_SS_Exon3,,5,AD007,CAGATC,IDX05,TAAGCT,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_SNP1,SQ0284_SS_SNP1,,6,AD004,TGACCA,IDX06,ATTCCG,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_SNP2,SQ0284_SS_SNP2,,7,AD004,TGACCA,IDX07,CGCAGA,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_SNP3,SQ0284_SS_SNP3,,8,AD004,TGACCA,IDX08,ACTCTT,Goat,Goat_SQ0284_PstI_GTseqSS
6,SQ0284_SS_SNP4,SQ0284_SS_SNP4,,9,AD016,CCGTCC,IDX08,ACTCTT,Goat,Goat_SQ0284_PstI_GTseqSS
7,SQ0285_998653,SQ0285_998653,,A01,AD002,CGATGT,IDX01,GAAATG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998656,SQ0285_998656,,A02,AD002,CGATGT,IDX02,GGACCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998657,SQ0285_998657,,A03,AD002,CGATGT,IDX03,CGAGGC,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998658,SQ0285_998658,,A04,AD002,CGATGT,IDX04,TCTTCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998659,SQ0285_998659,,A05,AD002,CGATGT,IDX05,TAAGCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998660,SQ0285_998660,,A06,AD002,CGATGT,IDX06,ATTCCG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998661,SQ0285_998661,,A07,AD002,CGATGT,IDX07,CGCAGA,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998662,SQ0285_998662,,A08,AD002,CGATGT,IDX08,ACTCTT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998663,SQ0285_998663,,A09,AD007,CAGATC,IDX01,GAAATG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998664,SQ0285_998664,,A10,AD007,CAGATC,IDX02,GGACCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998665,SQ0285_998665,,A11,AD007,CAGATC,IDX03,CGAGGC,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998666,SQ0285_998666,,A12,AD007,CAGATC,IDX04,TCTTcsvreader = csv.reader(csvfile)CT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998667,SQ0285_998667,,B01,AD007,CAGATC,IDX05,TAAGCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998668,SQ0285_998668,,B02,AD007,CAGATC,IDX06,ATTCCG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998669,SQ0285_998669,,B03,AD007,CAGATC,IDX07,CGCAGA,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998670,SQ0285_998670,,B04,AD007,CAGATC,IDX08,ACTCTT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998672,SQ0285_998672,,B05,AD004,TGACCA,IDX01,GAAATG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998673,SQ0285_998673,,B06,AD004,TGACCA,IDX02,GGACCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998674,SQ0285_998674,,B07,AD004,TGACCA,IDX03,CGAGGC,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998675,SQ0285_998675,,B08,AD004,TGACCA,IDX04,TCTTCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998676,SQ0285_998676,,B09,AD004,TGACCA,IDX05,TAAGCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998677,SQ0285_998677,,B10,AD004,TGACCA,IDX06,ATTCCG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998678,SQ0285_998678,,B11,AD004,TGACCA,IDX07,CGCAGA,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_998679,SQ0285_998679,,B12,AD004,TGACCA,IDX08,ACTCTT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71443,SQ0285_H71443,,C01,AD016,CCGTCC,IDX01,GAAATG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71411,SQ0285_H71411,,C02,AD016,CCGTCC,IDX02,GGACCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71456,SQ0285_H71456,,C03,AD016,CCGTCC,IDX03,CGAGGC,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71423,SQ0285_H71423,,C04,AD016,CCGTCC,IDX04,TCTTCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71428,SQ0285_H71428,,C05,ADsamplesheet_temp016,CCGTCC,IDX05,TAAGCT,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71433,SQ0285_H71433,,C06,AD016,CCGTCC,IDX06,ATTCCG,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71471,SQ0285_H71471,,C07,AD016,CCGTCC,IDX07,CGCAGA,Goat,Goat_SQ0285_PstI_GTseq32
7,SQ0285_H71464,SQ0285_H71464,,C08,AD016,CCGTCC,IDX08,ACTCTT,Goat,Goat_SQ0285_PstI_GTseq32
8,SQ0286,SQ0286,,,,,,,Deer,Deer_SQ0286_PstI



"""
import csv 
import sys
import re
import string
import argparse

def get_import_value(value_dict, regexp):
   matching_keys = [re.search(regexp, key, re.IGNORECASE).groups()[0] for key in value_dict.keys() if re.search(regexp, key, re.IGNORECASE) is not None]
   #print value_dict
   #print regexp
   #print matching_keys
   if len(matching_keys) == 0:
      value = ""
   elif len(matching_keys) == 1:
      value = value_dict[matching_keys[0]]
   else:
      value = "; ".join("%s=%s"%(key, value_dict[key]) for key in matching_keys)
   return value
   
   

def sanitise(options):

   get_value = lambda value_dict, other_key, regexp: "(%s) "%[value_dict[key] for key in value_dict.keys() if re.match(regexp, key. re.IGNORECASE) is not None]

   rowcount = 1
   numcol = None
   DEBUG=False

   csvreader = csv.reader(sys.stdin)
   csvwriter = csv.writer(sys.stdout)
   filter_record = True
   standard_header = ["fcid","lane","sampleid","sampleref","sampleindex","description","control","recipe","operator","sampleproject","sampleplate","samplewell"]

   for record in csvreader:
      
      if filter_record:
         # see if we have hit header
         #print record
         header_matches = [True for item in record if re.match("(lane|sample_id|sample_name)",item,re.IGNORECASE) is not None]
         #print header_matches
         if len(header_matches) == 3:
            filter_record = False
            header = record

            # output header
            csvwriter.writerow(standard_header)
      else:
         # prepare ther record, including the following mappings:
         #Lane->lane
         #Sample_ID->sampleid
         #Sample_Name->sampleref
         #Sample_Plate->sampleplate *
         #Sample_Well -> samplewell *
         #*Index* -> sampleindex (concatenate)
         #Sample_Project -> sampleproject
         #Description -> description
         record_dict = dict(zip(header, record))
         out_record_dict  = {}
         out_record_dict["fcid"] = options["fcid"]
         out_record_dict["lane"] = get_import_value(record_dict, "(lane)")
         out_record_dict["sampleid"] = get_import_value(record_dict, "(sample[_]*id)")
         out_record_dict["sampleref"] = get_import_value(record_dict, "(sampleref|sample[_]*name)")
         out_record_dict["sampleindex"] = get_import_value(record_dict, "(.*index.*)")
         out_record_dict["description"] = get_import_value(record_dict, "(description)")
         out_record_dict["control"] = get_import_value(record_dict, "(control)")
         out_record_dict["recipe"] = get_import_value(record_dict, "(recipe)")
         out_record_dict["operator"] = get_import_value(record_dict, "(operator)")
         out_record_dict["sampleproject"] = get_import_value(record_dict, "(sample[_]*project)")
         out_record_dict["sampleplate"] = get_import_value(record_dict, "(sample[_]*plate)")
         out_record_dict["samplewell"] = get_import_value(record_dict, "(sample[_]*well)")
         
                                    
         record = [out_record_dict.get(key,"") for key in standard_header]
         
         csvwriter.writerow(record)


def get_options():
   description = """
   """
   long_description = """

example : cat myfile.csv | sanitiseSampleSheet.py -r 161205_D00390_0274_AC9KW9ANXX


"""

   parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
   parser.add_argument('-r', dest='run', required=True , help="name of run")

   args = vars(parser.parse_args())

   # parse fcid
   mymatch=re.match("^\d+_\S+_\d+_.(\S+)", args["run"])
   if mymatch is None:
      raise Exception("unable to parse fcid from run")

   args["fcid"] = mymatch.groups()[0]
       
   return args

        
    
def main():
    options = get_options()
    sanitise(options)
    
        
                                
if __name__ == "__main__":
    main()


   
   
"""   
for record in csvreader =csv.reader(csvfile)sys.stdin:
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
"""
