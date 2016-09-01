#!/usr/bin/env python 

import os
import re
import itertools
import string
import exceptions
import argparse


header1="""<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
   "httpd://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<title>
peacock of %(run_name)s
</title>
</head>
<body>
"""

header2="""
<table width=90%% align=center>
<tr>
<td>
<font size="-1"> plot file name</font>
</td>
<td>
<h2> Lane 1 </h2> 
</td>
<td>
<h2> Lane 2 </h2> 
</td>
<td>
<h2> Lane 3 </h2> 
</td>
<td>
<h2> Lane 4 </h2> 
</td>
<td>
<h2> Lane 5 </h2> 
</td>
<td>
<h2> Lane 6 </h2> 
</td>
<td>
<h2> Lane 7 </h2> 
</td>
<td>
<h2> Lane 8 </h2> 
</td>
</tr>
"""

footer1="""
<h2> Blast Result Clustering </h2>
<table width="30%%" align=center>
<tr>
<td>
<img src="taxonomy_clustering.jpg"/>
</td>
</tr>
</table>
<h2> Read and tag yields</h2>
<table width="30%%" align=center>
<tr>
<td>
<img src="tags_summary.jpg"/>
</td>
</tr>
<tr>
<td>
<img src="read_summary.jpg"/>
</td>
</tr>
</table>
</body>
</html>
"""

BASEDIR="/dataset/hiseq/scratch/postprocessing"


def generate_run_plot(options):
    stats = {
        "found file count" : 0,
        "no file count" : 0,
        "no sample count" : 0
    }

    file_group_iter = ("KGD", "kmer_analysis")
    file_iters = {
        "KGD" : ['KGD/MAFHWdgm.05.png', 'KGD/SNPDepthHist.png', 'KGD/AlleleFreq.png', 'KGD/GHWdgm.05-diag.png', 'KGD/SNPDepth.png', 'KGD/finplot.png', 'KGD/Heatmap-G5HWdgm.05.png', 'KGD/SampDepth.png', 'KGD/G-diag.png', 'KGD/Gdiagdepth.png', 'KGD/LRT-hist.png', 'KGD/MAF.png', 'KGD/GcompareHWdgm.05.png', 'KGD/Gcompare.png', 'KGD/SampDepthHist.png', 'KGD/CallRate.png', 'KGD/GHWdgm.05diagdepth.png', 'KGD/Heatmap-G5.png', 'KGD/SampDepth-scored.png', 'KGD/HWdisMAFsig.png', 'KGD/LRT-QQ.png', 'KGD/SampDepthCR.png', 'KGD/PC1v2G5HWdgm.05.png'],
        "kmer_analysis" : ['kmer_analysis/kmer_zipfian_comparisons.jpg', 'kmer_analysis/zipfian_distances.jpg', 'kmer_analysis/kmer_entropy.jpg']
    }

    
    with open(options["output_filename"],"w") as out_stream:

        print >> out_stream, header1%options
        print >> out_stream, """<h1> Plots for <a href="http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=%(run_name)s&context=default">%(run_name)s</a> </h1>"""%options
        
        with open(options["key_file_summary"][0],"r") as in_stream:
            # get an iteration of dictionaries - this parses the tab-delimited file as
            # an iteration of 
            #{'lane': '6', 'run_number': '0286', 'run': '140818_SN871_0286_AC4U86ACXX', 'samplename': 'SQ0006', 'image_file_name': '140818_SN871_0286_AC4U86ACXX.gbs/SQ0006.processed_sample/uneak\n', 'species': 'Cattle,Cattle,Cattle....'}
            #{'lane': '7', 'run_number': '0286', 'run': '140818_SN871_0286_AC4U86ACXX', 'samplename': 'SQ0007', 'image_file_name': '140818_SN871_0286_AC4U86ACXX.gbs/SQ0007.processed_sample/uneak\n', 'species': 'Deer,Deer,Deer,...'}
            # etc
            # (the species column in the key-file summary contains a comma-separated list of 
            # all species listed in the keyfile. This is condensed below)
            sample_iter = (dict(zip(("run","run_number","lane","samplename","species","uneak_path"), re.split("\t", record.strip()))) for record in in_stream)
            sample_iter.next() # skip heading 
            
            # mak a list so we can add a species summary field - e.g. this will summarise 'sheep,sheep,cattle' as
            # 'cattle=1, sheep=2'
            sample_list = list(sample_iter)
            for sample in sample_list:
                sample["species_summary"] = ",".join(["=".join((group[0], str(len(list(group[1]))))) for group in itertools.groupby(sorted(re.split(",",sample["species"])))])
            sample_iter = (item for item in sample_list)

            # group by run
            run_iter = itertools.groupby(sample_iter, lambda sample_record:sample_record["run"])
            run_iter = itertools.ifilter(lambda item:item[0] == options["run_name"], run_iter)

            try:
                (run, sample_iter) = run_iter.next()
            except StopIteration:
                sample_iter = []

            run_samples = list(sample_iter)

            for file_group in file_group_iter:
                print >> out_stream, "<h2> %s </h2>"%file_group
                print >> out_stream, header2
                print >> out_stream, "<tr>"

                for image_file_name in file_iters[file_group]:
                    print >> out_stream, "<td>%s</td>"%image_file_name
                    for lane in range(1,9):
                        print >> out_stream,"<td align=center>"
                        samples = [ sample for sample in run_samples if int(sample["lane"]) == lane ]
                        if len(samples) > 1:
                            print "Error , more the one sample found for lane %d in run %s"%(lane,run)
                        elif len(samples) == 0:
                            print "could not find a sample for lane %d in run%s"%(lane, run)
                            print >> out_stream,"(no sample)"
                            stats["no sample count"] += 1
                        else:
                            relname = os.path.join("%(uneak_path)s"%samples[0], image_file_name)
                            if not os.path.isfile(os.path.join(BASEDIR,relname)):
                                print "file " + os.path.join(BASEDIR,relname) + " is unavailable for sample %(samplename)s in run %(run)s"%samples[0]
                                print >> out_stream, "<font size=-1> (unavailable for %(run)s) </font>"%samples[0]
                                stats["no file count"] += 1
                            else:
                                samples[0].update(options)
                                stats["found file count"] += 1
                                print >> out_stream, """
            <h3 align=center> %(species_summary)s </h3> <h4 align=center> <font size=-2>
            %(run)s <a href="http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=%(samplename)s&context=default"> %(samplename)s </a>
            </font></h4> 
            <img src="""%samples[0] + relname + """ height="%(image_height)s" width="%(image_width)s"/>
            """%samples[0]
                        print >> out_stream,"</td>"
                    print >> out_stream,"</tr>"
                print >> out_stream, "</table>"
                
            print >> out_stream, footer1

        print stats
                
                
def get_options():
    description = """
    """
    long_description = """
key file summary looks like :

run     run_number      lane    samplename      species image_file_name
140624_D00390_0044_BH9PEBADXX   0044    1       SQ0001  Deer    140624_D00390_0044_BH9PEBADXX.gbs/SQ0001.processed_sample/uneak/kmer_analysis/kmer_zipfian_comparisons.jpg
140624_D00390_0044_BH9PEBADXX   0044    2       SQ0001  Deer    140624_D00390_0044_BH9PEBADXX.gbs/SQ0001.processed_sample/uneak/kmer_analysis/kmer_zipfian_comparisons.jpg
140904_D00390_0209_BC4U6YACXX   0209    1       SQ0008  Deer    140904_D00390_0209_BC4U6YACXX.gbs/SQ0008.processed_sample/uneak/kmer_analysis/kmer_zipfian_comparisons.jpg
140904_D00390_0209_BC4U6YACXX   0209 

    """
    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('key_file_summary', type=str, nargs=1,metavar="key_file_summary", help='data listing basis of peacock')
    parser.add_argument('-r', '--run_name' , dest='run_name', required=True, type=str, help="run name")
    parser.add_argument('-H', '--image_height' , dest='image_height', default=300, type=int, help="image height")
    parser.add_argument('-W', '--image_width' , dest='image_width', default=300, type=int, help="image width")
    parser.add_argument('-o', '--output_filename' , dest='output_filename', default="peacock.html", type=str, help="name of output file")

    
    args = vars(parser.parse_args())

    # either input file or distribution file should exist 
    for file_name in args["key_file_summary"]:
        if not os.path.isfile(file_name):
            parser.error("could not find %s"%(file_name))
        break

    return args


def main():

    options = get_options()
    print options 

    generate_run_plot(options)

    
if __name__ == "__main__":
   main()



        

