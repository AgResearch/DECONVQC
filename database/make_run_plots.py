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
<h1> Deconvolution and Q/C results for <a href="http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=%(run_name)s&context=default">%(run_name)s</a> </h1>
<ul>
<li> <a href="#plots"> Plots </a>
<li> <a href="#spreadsheets"> Spreadsheet Summaries, Log files and Plot index pages </a>
<li> <a href="#references"> References </a>
<li> <a href="#notes"> Notes </a>

</ul>
"""

header2="""
<table id=plots width=90%% align=center>
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
<h2> Blast Result Clustering</h2>
<table width="30%%" align=center>
<tr>
<td>
<h3> Overview </h3>
</td>
</tr>
<tr>
<td>
%(blast_cluster_plot_link)s
</td>
</tr>
<tr>
<td>
<h3> By Species </h3>
</td>
</tr>
<tr>
<td align="left">
<img src="taxonomy_heatmaps.jpg" width=1000 height=8800/>
</td>
</tr>
</table>
<h2> Read and tag yields</h2>
<table width="30%%" align=center>
<tr>
<td>
<img src="tags_summary_%(run_name)s.jpg"/>
</td>
</tr>
<tr>
<td>
<img src="read_summary_%(run_name)s.jpg"/>
</td>
</tr>
</table>
<h2> Lane level kmer plots </h2>
<table width="30%%" align=center>
<tr>
<td>
<img src="%(run_name)s.processed/kmer_analysis/kmer_entropy.jpg"/>
</td>
</tr>
<tr>
<td>
<img src="%(run_name)s.processed/kmer_analysis/kmer_zipfian_comparisons.jpg"/>
</td>
</tr>
<tr>
<td>
<img src="%(run_name)s.processed/kmer_analysis/kmer_zipfian.jpg"/>
</td>
</tr>
</table>

<h2 id="spreadsheets"> Spreadsheet Summaries and Log Files</h2>
<table width=60%% align=left>
<tr>
<td>
Q/C Blast results by lane and species
</td>
<td>
<ul>
<li> <a href="all_freq.xlsx"> All </a>
<li> <a href="bacteria_freq.xlsx"> Just Bacteria  </a>
</ul>
</td>
</tr>

<tr>
<td>
Tag Counts by lane 
</td>
<td>
<ul>
<li> <a href="all_tag_count_summaries.xlsx"> Tag Counts </a>
</ul>
</td>
</tr>

<tr>
<td>
Plot Index Pages 
</td>
<td>
<ul>
<li> <a href="peacock_index.html"> By Plot Type (All samples) </a>
<p/>
<li> <a href="peacock_mussel_index.html"> By Plot Type (Mussel) </a>
<li> <a href="peacock_salmon_index.html"> By Plot Type (Salmon) </a>
<li> <a href="peacock_deer_index.html"> By Plot Type (Deer) </a>
<li> <a href="peacock_sheep_index.html"> By Plot Type (Sheep) </a>
<li> <a href="peacock_goat_index.html"> By Plot Type (Goat) </a>
<li> <a href="peacock_cattle_index.html"> By Plot Type (Cattle) </a>
<li> <a href="peacock_ryegrass_index.html"> By Plot Type (Ryegrass) </a>
<li> <a href="peacock_clover_index.html"> By Plot Type (Clover) </a>
<p/> 
<li> <a href="peacock_run_index.html"> By Run </a>
</ul>
</td>
</tr>

<tr>
<td>
pre-GBS Q/C 
</td>
<td>
<ul>
<li> <a href="%(run_name)s.processed/fastqc_analysis"> FASTQC </a>
<li> <a href="%(run_name)s.processed/taxonomy_analysis"> Blast Results </a> 
<li> <a href="%(run_name)s.processed/mapping_preview"> Mapping against Reference </a> 
</ul>
</td>
</tr>
</table>

<table width="30%%" align=center>
<tr>
<td>
<h2> Mapping Preview Summary  </h2>
<a href="stats_summary.txt"> Mapping Preview Summary (tab delimited text)</a>
<br/>
Mapping Preview Summary Plot:
<br/>
<img src="%(run_name)s.processed/mapping_preview/mapping_stats.jpg"/>
</td>
</tr>
</table>


<table>
<tr>
<td>
Illumina and other (pre-GBS) log files 
</td>
<td>
<ul>
<li> <a href="%(run_name)s.log"> pipeline log </a> 
<li> <a href="%(run_name)s_bcl2fastq.log"> bcl2fastq log </a>
<li> <a href="%(run_name)s_configureBclToFastq.log"> bcl2fastq configure log </a>
</ul>
</td>
</tr>


<tr>
<td>
GBS Q/C log files and results  
</td>
<td>
<ul>
<li> <a href="%(run_name)s.gbs"> GBS results </a>
<li> <a href="%(run_name)s.gbs.log"> GBS pipeline log </a> 
</ul>
</td>
</tr>
</table>


<table>
<tr>
<td>
<h2 id="references"> References </h2>
<ul>
<li> <a href="http://agbrdf.agresearch.co.nz/index.html">http://agbrdf.agresearch.co.nz/index.html</a>  has links to runs, sample sheets and key-files.
<li> DECONVQC source code and documentation : <a href="https://github.com/AgResearch/DECONVQC"> https://github.com/AgResearch/DECONVQC </a>
<li> Keyfile repo : <a href="https://hg.agresearch.co.nz/hg/gbs_keyfiles/"> https://hg.agresearch.co.nz/hg/gbs_keyfiles/ </a> 
</ul>
</td>
</tr>

<tr>
<td>
<h2 id="notes"> Notes </h2>
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

    file_group_iter = (("KGD plots", "image"), ("KGD links", "link"), ("kmer and blast analysis", "image"))
    file_iters = {
        #"KGD" : ['KGD/MAFHWdgm.05.png', 'KGD/SNPDepthHist.png', 'KGD/AlleleFreq.png', 'KGD/GHWdgm.05-diag.png', 'KGD/SNPDepth.png', 'KGD/finplot.png', 'KGD/Heatmap-G5HWdgm.05.png', 'KGD/SampDepth.png', 'KGD/G-diag.png', 'KGD/Gdiagdepth.png', 'KGD/LRT-hist.png', 'KGD/MAF.png', 'KGD/GcompareHWdgm.05.png', 'KGD/Gcompare.png', 'KGD/SampDepthHist.png', 'KGD/CallRate.png', 'KGD/GHWdgm.05diagdepth.png', 'KGD/Heatmap-G5.png', 'KGD/SampDepth-scored.png', 'KGD/HWdisMAFsig.png', 'KGD/LRT-QQ.png', 'KGD/SampDepthCR.png', 'KGD/PC1v2G5HWdgm.05.png'],
        "KGD plots" : ['KGD/AlleleFreq.png', 'KGD/finplot.png', 'KGD/G-diag.png', 'KGD/HWdisMAFsig.png', 'KGD/MAF.png', 'KGD/SampDepth.png', 'KGD/SNPDepth.png',
                'KGD/CallRate.png', 'KGD/GcompareHWdgm.05.png', 'KGD/GHWdgm.05diagdepth.png', 'KGD/LRT-hist.png', 'KGD/PC1v2G5HWdgm.05.png', 'KGD/SampDepth-scored.png'
                'KGD/Co-call-HWdgm.05.png', 'KGD/Gcompare.png', 'KGD/GHWdgm.05-diag.png', 'KGD/LRT-QQ.png', 'KGD/SampDepthCR.png', 'KGD/SNPCallRate.png'
                'KGD/Co-call-.png', 'KGD/Gdiagdepth.png', 'KGD/Heatmap-G5HWdgm.05.png', 'KGD/MAFHWdgm.05.png', 'KGD/SampDepthHist.png', 'KGD/SNPDepthHist.png'],
        "KGD links" : ['KGD/kgd.stdout', 'KGD/HeatmapOrderHWdgm.05.csv', 'KGD/PCG5HWdgm.05.pdf', 'KGD/SampleStats.csv', 'KGD/HighRelatedness.csv', 'KGD/seqID.csv', 'KGD/HighRelatednessHWdgm.05.csv'],        
        "kmer and blast analysis" : ['blast_analysis/sample_blast_summary.jpg', 'kmer_analysis/kmer_zipfian_comparisons.jpg', 'kmer_analysis/zipfian_distances.jpg', 'kmer_analysis/kmer_entropy.jpg']
    }

    
    with open(options["output_filename"],"w") as out_stream:
        print >> out_stream, header1%options
        
        with open(options["key_file_summary"][0],"r") as in_stream:
            # get an iteration of dictionaries - this parses the tab-delimited file as
            # an iteration of 
            #{'lane': '6', 'run_number': '0286', 'run': '140818_SN871_0286_AC4U86ACXX', 'samplename': 'SQ0006', 'file_name': '140818_SN871_0286_AC4U86ACXX.gbs/SQ0006.processed_sample/uneak\n', 'species': 'Cattle,Cattle,Cattle....'}
            #{'lane': '7', 'run_number': '0286', 'run': '140818_SN871_0286_AC4U86ACXX', 'samplename': 'SQ0007', 'file_name': '140818_SN871_0286_AC4U86ACXX.gbs/SQ0007.processed_sample/uneak\n', 'species': 'Deer,Deer,Deer,...'}
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

            # group by run, and filter to get just this run 
            run_iter = itertools.groupby(sample_iter, lambda sample_record:sample_record["run"])
            run_iter = itertools.ifilter(lambda item:item[0] == options["run_name"], run_iter)

            try:
                (run, sample_iter) = run_iter.next()
            except StopIteration:
                sample_iter = []

            run_samples = list(sample_iter)

            for (file_group, file_type)  in file_group_iter:
                print >> out_stream, "<h2> %s </h2>"%file_group
                print >> out_stream, header2
                print >> out_stream, "<tr>"

                for file_name in file_iters[file_group]:
                    print >> out_stream, "<td>%s</td>"%file_name
                    for lane in range(1,9):
                        print >> out_stream,"<td align=center>"
                        samples = [ sample for sample in run_samples if int(sample["lane"]) == lane ]
                        if len(samples) > 1:
                            print "Error , more the one sample found for lane %d in run %s"%(lane,options["run_name"])
                        elif len(samples) == 0:
                            print "could not find a sample for lane %d in run%s"%(lane, options["run_name"])
                            print >> out_stream,"(no sample)"
                            stats["no sample count"] += 1
                        else:
                            relnames = [os.path.join("%(uneak_path)s"%samples[0], file_name)]   # usually there is just one file to display but there may be more
                            if not os.path.isfile(os.path.join(BASEDIR,relnames[0])):
                                # in some cases there are one or more links to the requested file - look for all of these
                                # by filtering the real paths of all links in the bottom level folder
                                #print "DEBUG trying links" 
                                found_relnames = []
                                try:
                                    path = os.path.dirname(os.path.join(BASEDIR,relnames[0]))
                                    base = os.path.basename(os.path.join(BASEDIR,relnames[0]))
                                    #print "DEBUG looking for links in %s with base %s"%(path, base)
                                    #print "DEBUG searching these links : %s"%str([filename for filename in os.listdir(path) if os.path.islink(filename)])
                                    

                                    found_relnames = [ os.path.relpath(os.path.join(path,filename), BASEDIR) for filename in os.listdir(path) if os.path.islink(os.path.join(path,filename)) and
                                             os.path.basename(os.path.realpath(os.path.join(path,filename))) == base ]
                                    print "DEBUG found_relnames = %s"%str(found_relnames)
                                except:
                                    pass
                                    
                                if len(found_relnames) > 0:
                                    relnames = found_relnames

                            if not os.path.isfile(os.path.join(BASEDIR,relnames[0])): 
                                print "file " + os.path.join(BASEDIR,relnames[0]) + " is unavailable for sample %(samplename)s in run %(run)s"%samples[0]
                                print >> out_stream, "<font size=-1> (unavailable for %(run)s) </font>"%samples[0]
                                stats["no file count"] += 1
                            else:
                                samples[0].update(options)
                                stats["found file count"] += 1
                                if file_type == "image":
                                    print >> out_stream, """
                <h3 align=center> %(species_summary)s </h3> <h4 align=center> <font size=-2>
                %(run)s <a href="http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=%(samplename)s&context=default"> %(samplename)s </a>
                </font></h4>"""%samples[0]
                                    for relname in relnames:
                                        print >> out_stream,"""
                <img src=""" + relname + """ title=""" + relname + """ height="%(image_height)s" width="%(image_width)s"/>
                """%samples[0]
                                else:
                                    print >> out_stream, """
                <h3 align=center> %(species_summary)s </h3> <h4 align=center> <font size=-2>
                %(run)s <a href="http://agbrdf.agresearch.co.nz/cgi-bin/fetch.py?obid=%(samplename)s&context=default"> %(samplename)s </a>
                </font></h4>"""%samples[0]
                                    for relname in relnames:
                                        print >> out_stream,"""
                <a href=""" + relname + """ target=new >""" + os.path.basename(relname)+ """ </a>
                """%samples[0]
                        print >> out_stream,"</td>"
                    print >> out_stream,"</tr>"
                print >> out_stream, "</table>"

            options["blast_cluster_plot_link"] = "<img src=\"taxonomy_clustering_%(run_name)s.jpg\"/>"%options
            if not os.path.isfile(os.path.join(BASEDIR,"taxonomy_clustering_%(run_name)s.jpg"%options)): 
                options["blast_cluster_plot_link"] = "<font size=-1> (unavailable) </font>" 
            

            print >> out_stream, footer1%options



        print stats
                
                
def get_options():
    description = """
    """
    long_description = """
key file summary looks like :

run     run_number      lane    samplename      species file_name
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



        

