# 
#-------------------------------------------------------------------------
# barplot propotion of bacterial hits 
#-------------------------------------------------------------------------

# libraries
data_folder="/dataset/hiseq/scratch/postprocessing/"     
output_folder="/dataset/hiseq/scratch/postprocessing/" 

setwd(data_folder) 
all_freqs = read.table("all_frequency.txt", header=TRUE, row.names=1, sep="\t")
bacteria_freqs = read.table("bacteria_frequency.txt", header=TRUE, row.names=1, sep="\t")

bacterial_percent = 100 * colSums(bacteria_freqs)/colSums(all_freqs)

# calculate bar plot height
height=ncol(all_freqs) * 1600/281
jpeg("bacterial_proportions.jpg", 600, height)
barplot(bacterial_percent, main="Percentage Bacterial Hits",  xlab="Percentage Bacterial Hits", 
          ylab="Sample", horiz=TRUE, cex.axis=1.5)
dev.off()