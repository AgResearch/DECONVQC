#!/usr/bin/env python 

import os
import itertools
import string
import math
import re
import argparse
from multiprocessing import Pool
from prbdf import Distribution , build, PROC_POOL_SIZE, from_tab_delimited_file, bin_discrete_value

RUN_ROOT="/dataset/hiseq/scratch/postprocessing"
BUILD_ROOT="/dataset/hiseq/scratch/postprocessing/analysis"


def my_weight_value_provider(raw_value, *xargs):
    weight_value = ((raw_value[2], raw_value[0],raw_value[1]),)
    return weight_value


def build_run_tax_distributions(run_name, tax_pattern = None, name_infix=""):
    """
     the input tax table looks like  :

     Kingdom Family  Sample_SQ0032   Sample_SQ2525   Sample_SQ2526   Sample_SQ2527   Sample_SQ2528   Sample_SQ2529   Sample_SQ2530   Sample_SQ2531
B       Actinoplanes friuliensis DSM 7358       0       0       0       0       3       0       0       0
B       Variovorax paradoxus B4 0       0       0       0       1       1       1       0
Bacteria        Achromobacter xylosoxidans      1       0       0       0       4       2       0       0
Bacteria        Achromobacter xylosoxidans A8   1       0       0       0       4       7       0       0
Bacteria        Achromobacter xylosoxidans C54  0       0       0       0       2       4       0       0
Bacteria        Acidiphilium multivorum AIU301  0       0       0       0       0       0       1       0
Bacteria        Acidovorax avenae subsp. avenae ATCC 19860      1       0       0       0       0       1       1       0
Bacteria        Acidovorax avenae subsp. citrulli AAC00-1       0       0       0       0       1       0       0       0
Bacteria        Acidovorax sp. KKS102   0       1       0       0       1       8       0       1
Bacteria        Acinetobacter baumannii 0       0       0       0       0       1       0       0

    """

    global RUN_ROOT, BUILD_ROOT

    # get the number of samples
    run_taxtable_file = os.path.join(RUN_ROOT, "%s.processed"%run_name, "taxonomy_analysis", "samples_taxonomy_table.txt")
    data_stream = from_tab_delimited_file(run_taxtable_file)

    sample_names = data_stream.next()[2:]
    #print "building distributions for samples %s in run %s"%(str(sample_names), run_name)
    saved_files = []
    
    for sample_name in sample_names:
        #print "processing %s"%sample_name
        saved_file = build_sample_tax_distribution(run_taxtable_file,run_name,sample_name,tax_pattern,name_infix)
        #use_prbdf(saved_file)
        saved_files.append(saved_file)

    return saved_files


def build_sample_tax_distribution(datafile, run_name, sample_name, tax_pattern = None, name_infix=""):
    """
    each record - i.e. taxa - is a bin. Build a distribution of reads across
    these bins, for each sample in a run. This is already provided by the summary files - we just collate
    all summary files and store it our own sparse prbdf structure

    (tax_pattern and name_infix are there for selecting out sub-sets of taxa)
    """
    global RUN_ROOT, BUILD_ROOT
    

    #print "building sample tax distribution for %s:%s using %s"%(run_name, sample_name, datafile)

    data_stream = from_tab_delimited_file(datafile)
    header  = data_stream.next()
    sample_index = header.index(sample_name)
    if tax_pattern is None:
        data_stream = ((record[0],record[1],record[sample_index]) for record in data_stream if float(record[sample_index]) > 0) # taxname, count
    else:
        data_stream = ((record[0],record[1],record[sample_index]) for record in data_stream if float(record[sample_index]) > 0 and re.search(tax_pattern, record[0], re.IGNORECASE) is not None) # taxname, count

    distob = Distribution(None, 1, [data_stream]) 

    distob.interval_locator_funcs = [bin_discrete_value, bin_discrete_value]
    distob.assignments_files = ["kingdom_binning.txt", "family_binning.txt"]
    distob.weight_value_provider_func = my_weight_value_provider
    distdata = build(distob,"singlethread")
    save_filename = os.path.join(BUILD_ROOT,"%s_%s_%s.pickle"%(run_name, sample_name, name_infix))
    if len(name_infix) > 0:
        save_filename =  os.path.join(BUILD_ROOT,"%s_%s_%s.pickle"%(run_name, sample_name, name_infix))
    else:
        save_filename =  os.path.join(BUILD_ROOT,"%s_%s.pickle"%(run_name, sample_name))
    distob.save(save_filename)
        
    #print "Distribution %s:%s has %d points distributed over %d intervals, stored in %d parts"%(run_name, sample_name,distob.point_weight, len(distdata), len(distob.part_dict))

    return save_filename
    

def get_all_tax_intervals(distribution_files, name_infix):
    # several ways of doing this - e.g. just make a set out of a list of all of them, however
    # will do it using the distribution builder
    global RUN_ROOT, BUILD_ROOT
    
    interval_readers = [ Distribution.load(distribution_file).get_distribution().keys() for distribution_file in distribution_files ]   

    distob = Distribution([], 1, interval_readers)

    distob.interval_locator_funcs = (bin_discrete_value,bin_discrete_value,)
    distob.assignments_files = ("kingdom_binning.txt","family_binning.txt")
    distdata = build(distob)
    distob.summary()
    if len(name_infix) > 0:
        save_filename =  os.path.join(BUILD_ROOT,"all_taxa_%s.pickle"%name_infix)
    else:
        save_filename =  os.path.join(BUILD_ROOT,"all_taxa.pickle")
    distob.save(save_filename)
    return save_filename
    
    

def use_prbdf(picklefile):
    distob = Distribution.load(picklefile)
    distob.list()

def get_tax_interval_measure_space(measure, all_taxa_distribution, run_distributions):


    all_intervals_list = Distribution.load(all_taxa_distribution).get_distribution().keys()
        
    all_intervals_list.sort()
    
    sample_measures = Distribution.get_projections(run_distributions, all_intervals_list, measure)
    zsample_measures = itertools.izip(*sample_measures)
    sample_name_iter = [tuple([os.path.splitext(os.path.basename(run_distribution))[0] for run_distribution in run_distributions])]
    zsample_measures = itertools.chain(sample_name_iter, zsample_measures)
    
                                                                                                                                                            
    interval_name_iter = itertools.chain([("kingdom","family")],all_intervals_list)
    zsample_measures_with_rownames = itertools.izip(interval_name_iter, zsample_measures)
    return (zsample_measures, zsample_measures_with_rownames)


        

def get_options():
    description = """
This script summarises the taxonomy blasts globally across all hiseq runs 
example :

python hiseq_taxonomy.py -t frequency 150619_D00390_0230_AC6JPUANXX 150612_D00390_0228_AC6JPWANXX 150226_D00390_0218_BC4TWKACXX 150515_D00390_0227_BC6JPMANXX 150630_D00390_0232_AC6K0WANXX 150630_D00390_0233_BC6JRFANXX 150508_D00390_0226_AC6H4RANXX 150626_D00390_0231_BC6JT3ANXX 141217_D00390_0214_BC4UEHACXX 150615_D00390_0229_BC6JT1ANXX 150506_D00390_0225_BC6K2RANXX 150429_D00390_0224_AC6GHKANXX 150810_D00390_0234_AC6JTHANXX 150925_D00390_0235_BC6K0YANXX 151016_D00390_0236_AC6JURANXX   
python hiseq_taxonomy.py -t information 150619_D00390_0230_AC6JPUANXX 150612_D00390_0228_AC6JPWANXX 150226_D00390_0218_BC4TWKACXX 150515_D00390_0227_BC6JPMANXX 150630_D00390_0232_AC6K0WANXX 150630_D00390_0233_BC6JRFANXX 150508_D00390_0226_AC6H4RANXX 150626_D00390_0231_BC6JT3ANXX 141217_D00390_0214_BC4UEHACXX 150615_D00390_0229_BC6JT1ANXX 150506_D00390_0225_BC6K2RANXX 150429_D00390_0224_AC6GHKANXX 150810_D00390_0234_AC6JTHANXX 150925_D00390_0235_BC6K0YANXX 151016_D00390_0236_AC6JURANXX   


    """
    long_description = """
    """
    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('run_names', type=str, nargs='*',help='list of runs to include')
    parser.add_argument('-t', '--summary_type' , dest='summary_type', default="frequency", choices=["frequency", "information"],help="type of summary")    
    parser.add_argument('-s', '--subset' , dest='subset', default="all", choices=["eukaryota", "bacteria", "all"],help="subset to summarise")    
    parser.add_argument('-o', '--outfile' , dest='outfile', default="tax.out", required=True,help="name of output file")    
    
    args = vars(parser.parse_args())

    return args




def main():

    subsets = {
       "eukaryota" : "^Eukaryota",
       "bacteria" : "^Bacteria",
       "all" : None
    }
    summary_types = {
       "frequency" : "frequency",
       "information" : "unsigned_information"
    }

    options = get_options()
    run_distribution_files = []
    for run in options["run_names"]:
        run_distribution_files += build_run_tax_distributions(run,tax_pattern = subsets[options["subset"]], name_infix=options["subset"])
    #print run_distribution_files

    all_taxa_distribution_file = get_all_tax_intervals(run_distribution_files, name_infix = options["subset"])

    (space_iter, space_iter_with_rownames) = get_tax_interval_measure_space(summary_types[options["summary_type"]], all_taxa_distribution_file, run_distribution_files)

    with open(options["outfile"],"w") as outfile:
        for interval_measure in space_iter_with_rownames:
            print >> outfile, re.sub("'|#","","%s\t%s"%("%s_%s"%interval_measure[0], string.join((str(item) for item in interval_measure[1]),"\t")))

    return     
    
if __name__ == "__main__":
   main()



        
