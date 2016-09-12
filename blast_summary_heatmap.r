library(Heatplus)
library(RColorBrewer)
library("gplots")

get_command_args <- function() {
   args=(commandArgs(TRUE))
   if(length(args)!=1 ){
      #quit with error message if wrong number of args supplied
      print('Usage example : Rscript --vanilla  blast_summary_heatmap.r datafolder=/dataset/hiseq/scratch/postprocessing/160623_D00390_0257_AC9B0MANXX.gbs/SQ2559.processed_sample/uneak/kmer_analysis')
      print('args received were : ')
      for (e in args) {
         print(e)
      }
      q()
   }else{
      print("Using...")
      # seperate and parse command-line args
      for (e in args) {
         print(e)
         ta <- strsplit(e,"=",fixed=TRUE)
         switch(ta[[1]][1],
            "datafolder" = datafolder <- ta[[1]][2]
         )
      }
   }
   return(datafolder)
}

draw_heatmap <- function() {
   datamatrix<-read.table("blast_information_table.txt", header=TRUE, row.names=2, sep="\t")
   datamatrix <- subset(datamatrix, select = -c(Kingdom) )

   # want to plot 20 broad taxonomy profiles - so cluster the profiles
   num_clust=20   # all 
   clustering <- kmeans(datamatrix, num_clust, iter.max=500)


   # label each profile with the name of the species whose profile
   # is closest to the center of each cluster - so find these

   closest_dists = rep(NA,nrow(clustering$centers))
   closest_rownums = rep(NA,nrow(clustering$centers))

   for (center_num in sequence(nrow(clustering$centers))) {
      v_center = as.numeric(clustering$centers[center_num,])
      for (row_num in sequence(nrow(datamatrix))) {
         v_data = as.numeric(datamatrix[row_num,])
         d = (v_center - v_data) %*% (v_center - v_data)
         if(is.na(closest_dists[center_num])) {
            closest_dists[center_num] = d
            closest_rownums[center_num] = row_num
         }
         else if( d < closest_dists[center_num] ) {
            closest_dists[center_num] = d
            closest_rownums[center_num] = row_num
         }
      }
   }

   # assign the labels to the clustered data
   rownames=rownames(datamatrix)[closest_rownums]
   clustered_data = clustering$centers
   rownames(clustered_data) = rownames


   # draw the heatmap in the usual way
   cm<-brewer.pal(11,"Spectral") # a diverging palette


   # set up a vector which will index the labels that are to be blanked out so that 
   # only every nth col is labelled, 
   # the rest empty strings, n=col_label_interval.
   number_of_column_labels=40
   col_label_interval=max(1, floor(ncol(clustered_data)/number_of_column_labels))  # 1=label every location 2=label every 2nd location  etc 
   colLabels <- colnames(as.matrix(clustered_data))
   colBlankSelector <- sequence(length(colLabels))
   colBlankSelector <- subset(colBlankSelector, colBlankSelector %% col_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)


   # initial plot to get the column re-ordering
   jpeg(filename = "hm_internal.jpg" , width=830, height=1200) # with dendrograms

   hm<-heatmap.2(as.matrix(clustered_data),  scale = "none", 
   #hm<-heatmap.2(as.matrix(datamatrix),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/11*seq(0,11), 
       col = cm , key=TRUE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(17,28), cexRow=1.5, cexCol=1.6, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .6, 0 ), lhei=c(.5, 3))

  dev.off()


   # edit the re-ordered vector of col labels, obtained from the heatmap object, so that only 
   # every nth label on the final plot has a non-empty string
   # this is for the internal distance matrix
   indexSelector <- hm$colInd[length(hm$colInd):1]    
   indexSelector <- indexSelector[colBlankSelector]
   colLabels[indexSelector] = rep('',length(indexSelector))

   jpeg(filename = "sample_blast_summary.jpg", width=1200, height=1200) # with dendrograms
   hm<-heatmap.2(as.matrix(clustered_data),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/11*seq(0,11), 
       col = cm , key=TRUE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(27,28), cexRow=3.0, cexCol=1.2, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .6, 0 ), lhei=c(.25, 3),labCol=colLabels)

   dev.off()
}

main <- function() {
   data_folder <- get_command_args()
   setwd(data_folder)
   draw_heatmap()
}


main()


