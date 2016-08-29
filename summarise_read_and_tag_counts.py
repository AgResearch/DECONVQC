#!/usr/bin/env python
import itertools
import argparse
import os
import re
import math
from prbdf import from_csv_file

def get_summary(filename):
    """
    parse a CSV file like
    
    sample	flowcell	lane	sq	tags	reads
total	C89NRANXX	2	SQ0170		213806472
good	C89NRANXX	2	SQ0170		201374488
F1506238	C89NRANXX	2	170	307411	1139674
F1506739	C89NRANXX	2	170	336999	1502266
F1506080	C89NRANXX	2	170	301157	1083759
.
.
.
and summarise it

    """
    print "summarising %s"%filename
    (tuple_stream, exclusions_stream)= itertools.tee(from_csv_file(filename))

    header=tuple_stream.next()
    if header[0].lower() != "sample":
        raise Exception("""
%s does not look like a CSV tag count summary - first record should be heading, first column should be sample
first record is :
%s
"""%(filename, str(header)))



    tuple_stream = itertools.ifilter( lambda record: not ((record[0].lower() in ("total","good")) or ( re.search("blank|gbsneg|negative", record[0], re.IGNORECASE) is not None )), tuple_stream)
    exclusions_stream = itertools.ifilter(lambda record: ((record[0].lower() in ("total","good")) or ( re.search("blank|gbsneg|negative", record[0], re.IGNORECASE) is not None )), exclusions_stream)
    
                                        
    excluded = list(exclusions_stream)
    print "Excluded the following records : %s"%str(excluded)

    # get the flowcell and SQ names from those first excluded records
    flowcell=excluded[0][1]
    sq =excluded[0][3]    
    
                                                                  
    tags_reads = list((int(record[4]), int(record[5]), record[1], record[3]) for record in tuple_stream)

    #print "DEBUG : %s"%str(tags_reads)


    # calculate mean and standard deviation
    #print "DEBUG : %d"%sum((record[0] for record in tags_reads))
    mean_tag_count = sum((record[0] for record in tags_reads))/float(len(tags_reads))
    mean_read_count = sum((record[1] for record in tags_reads))/float(len(tags_reads))
    std_tag_count = math.sqrt(reduce(lambda x,y:x+y , map(lambda x: (x-mean_tag_count)**2 , (record[0] for record in tags_reads))) / float(len(tags_reads)))
    std_read_count = math.sqrt(reduce(lambda x,y:x+y , map(lambda x: (x-mean_read_count)**2 , (record[1] for record in tags_reads))) / float(len(tags_reads)))

    #calculate max and min
    min_tag_count = min((record[0] for record in tags_reads))
    min_read_count = min((record[1] for record in tags_reads))
    max_tag_count = max((record[0] for record in tags_reads))
    max_read_count = max((record[1] for record in tags_reads))



    return map(lambda x:str(x), ("%s_%s"%(flowcell,sq),mean_tag_count, std_tag_count, min_tag_count, max_tag_count, mean_read_count, std_read_count, min_read_count, max_read_count))
    


def get_summaries(options):

    header = [("flowcell_sq","mean_tag_count", "std_tag_count", "min_tag_count", "max_tag_count", "mean_read_count", "std_read_count", "min_read_count", "max_read_count")]
    summary_iter = (get_summary(filename) for filename in options["filenames"])
    

    return itertools.chain(header, summary_iter)



def get_options():
    description = """
    """
    long_description = """
    example:

    summarise_read_and_tag_counts.py /dataset/hiseq/scratch/postprocessing/160219_D00390_0245_AC89NRANXX.gbs/SQ0170.processed_sample/uneak/TagCount.csv
   
    """

    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('filenames', type=str, nargs="+",help='input files')    
    parser.add_argument('-o', '--output_filename' , dest='output_filename', default="tags_reads_summary.txt", type=str, help="output file name")
  

    
    args = vars(parser.parse_args())

    for filename in args["filenames"]:
        if not os.path.isfile(filename):
            raise Exception("error %s not found"%filename)

    if os.path.exists(args["output_filename"]):
        raise Exception("error output %s already exists - not over-writing"%args["output_filename"])

    return args

        
    
def main():
    options=get_options()

    with open(options["output_filename"],"w") as outfile:
        for summary_record in get_summaries(options):
            print >> outfile, "\t".join(summary_record)
    
    return

                                
if __name__ == "__main__":
   main()



        

