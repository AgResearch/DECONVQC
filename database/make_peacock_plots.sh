#!/bin/bash

PEACOCK_DATA=$1
if [ -z $PEACOCK_DATA ]; then
   echo "usage : make_peacock_plots.sh peacock_data_file"
   exit 1
fi
if [ ! -f $PEACOCK_DATA ]; then
   echo "make_peacock_plots.sh : input data $PEACOCK_DATA not found"
   exit 1
fi

if [ -z "$GBS_BIN" ]; then
   echo "GBS_BIN not set - exiting"
   exit 1
fi

echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"
   \"httpd://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
<html>
<head>
<title>
peacock plot index
</title>
</head>
<body>
<table width=90% align=center>
<tr>
<td>
<h3 align=center>
Note that these pages present diagnostic plots across many
different species and projects, as part of our internal quality
control and improvement processes. Please treat these data as
confidential.
</h3>
</td>
</tr>
<tr>
<td>
<h2> KGD plots </h2>
" > /dataset/hiseq/scratch/postprocessing/peacock_index.html

for plot_file in 'KGD/MAFHWdgm.05.png' 'KGD/SNPDepthHist.png' 'KGD/AlleleFreq.png' 'KGD/GHWdgm.05-diag.png' 'KGD/SNPDepth.png' 'KGD/finplot.png' 'KGD/Heatmap-G5HWdgm.05.png' 'KGD/SampDepth.png' 'KGD/G-diag.png' 'KGD/Gdiagdepth.png' 'KGD/LRT-hist.png' 'KGD/MAF.png' 'KGD/GcompareHWdgm.05.png' 'KGD/Gcompare.png' 'KGD/SampDepthHist.png' 'KGD/CallRate.png' 'KGD/GHWdgm.05diagdepth.png' 'KGD/Heatmap-G5.png' 'KGD/SampDepth-scored.png' 'KGD/HWdisMAFsig.png' 'KGD/LRT-QQ.png' 'KGD/SampDepthCR.png' 'KGD/PC1v2G5HWdgm.05.png' ; do
   base=`basename $plot_file`
   suffix=`basename $base .png`
   $GBS_BIN/database/make_peacock_plots.py -f $plot_file -o /dataset/hiseq/scratch/postprocessing/peacock_${suffix}.html $PEACOCK_DATA
   echo "<li> <a href=peacock_${suffix}.html> ${suffix} </a> </li>" >> /dataset/hiseq/scratch/postprocessing/peacock_index.html
done

echo "
<p/>
<h2> Sample blast plots </h2> " >> /dataset/hiseq/scratch/postprocessing/peacock_index.html

for plot_file in 'blast_analysis/sample_blast_summary.jpg' ; do
   base=`basename $plot_file`
   suffix=`basename $base .jpg`
set -x
   $GBS_BIN/database/make_peacock_plots.py -f $plot_file -o /dataset/hiseq/scratch/postprocessing/peacock_${suffix}.html $PEACOCK_DATA 
set +x
   echo "<li> <a href=peacock_${suffix}.html> ${suffix} </a> </li>" >> /dataset/hiseq/scratch/postprocessing/peacock_index.html
done

echo "
<p/>
<h2> k-mer analysis plots </h2> " >> /dataset/hiseq/scratch/postprocessing/peacock_index.html

for plot_file in 'kmer_analysis/kmer_zipfian_comparisons.jpg' 'kmer_analysis/kmer_entropy.jpg' 'kmer_analysis/zipfian_distances.jpg' ; do
   base=`basename $plot_file`
   suffix=`basename $base .jpg`
   $GBS_BIN/database/make_peacock_plots.py -f $plot_file -o /dataset/hiseq/scratch/postprocessing/peacock_${suffix}.html $PEACOCK_DATA 
   echo "<li> <a href=peacock_${suffix}.html> ${suffix} </a> </li>" >> /dataset/hiseq/scratch/postprocessing/peacock_index.html
done



echo "
</td>
</tr>
</table>
</body>
</html> " >>  /dataset/hiseq/scratch/postprocessing/peacock_index.html

