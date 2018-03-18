# 
library(Heatplus)
library(RColorBrewer)
library("gplots")
library("matrixStats")

setwd("/dataset/hiseq/scratch/postprocessing/")

get_command_args <- function() {
   args=(commandArgs(TRUE))
   if(length(args)!=1 ){
      #quit with error message if wrong number of args supplied
      print('Usage example : Rscript --vanilla  taxonomy_clustering.r run_name=160623_D00390_0257_AC9B0MANXX')
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
            "run_name" = run_name <- ta[[1]][2]
         )
      }
   }
   return(run_name)
}


get_species_info <- function(datamatrix) {
   sample_species_table<-read.table("sample_species.txt", header=TRUE, row.names=1, sep="\t")
   species_config_table<-read.table("species_config.txt", header=TRUE, row.names=1, sep="\t")
   sample_names <- strsplit(rownames(t(datamatrix)), split="_")
   get_name <- function(split_result) unlist(split_result)[5]
   sample_names <- sapply(sample_names, get_name) 
  
   # look up the species in the sample-species table , using sample name as key
   get_species <- function(sample_name) as.vector(sample_species_table[sample_name, "species"])[1]
   species_names <- sapply(sample_names, get_species)
   species_names <- sapply(species_names, tolower)

   # for each species in the species_config table, use the regexp 
   # in that table to locate the matching samples, and hence set the 
   # appropriate plot colour 
   point_colours <- rep("black", length(species_names)) 
   point_colours[1:(length(point_colours)-8)]<-NA

   point_symbols <- rep('?', length(species_names))
   point_count <- 1
   #print( species_names )
   for(rowname in rownames(species_config_table)) {
      regexp <-  toString(species_config_table[rowname, "regexp"])
      colour <- paste("#", toString(species_config_table[rowname, "colour"]),sep="")
      symbol <- toString(species_config_table[rowname, "symbol"]) 
      #print(paste("regexp=",regexp,sep=""))
      #print( species_names[grep(regexp,species_names, ignore.case = TRUE)] )
      #point_colours[ grep(regexp,species_names, ignore.case = TRUE) ] <- colour
      #point_symbols[ grep(regexp,species_names, ignore.case = TRUE) ] <- symbol
      matches <- grep(regexp,species_names, ignore.case = TRUE, value=FALSE)
      #print(paste("regexp=",regexp,sep=""))
      #print(matches)
      #print( species_names[matches] )

      point_colours[ matches ] <- colour
      point_symbols[ matches ] <- symbol

   }

   results=list()
   results$point_symbols = point_symbols
   results$point_colours = point_colours
   results$sample_names = sample_names
   return(results)
}



get_clusters <- function(datamatrix) {
   num_clust=20   # all 
   num_clust=20   # euk only
   clustering <- kmeans(datamatrix, num_clust, iter.max=500)
   tcenters=t(clustering$centers)
   distances <- dist(tcenters)
   
   species_info <- get_species_info(datamatrix)

   distances = dist(as.matrix(t(datamatrix)))

   fit <- cmdscale(distances,eig=TRUE, k=2)

   results=list()
   results$fit = fit
   results$point_symbols = species_info$point_symbols
   results$point_colours = species_info$point_colours
   results$sample_names = species_info$sample_names

   return(results)
}


stroverlap <- function(x1,y1,s1, x2,y2,s2) {
   # ref : https://stackoverflow.com/questions/6234335/finding-the-bounding-box-of-plotted-text
   # example : stroverlap(.5,.5,"word", .6,.5, "word")
   sh1 <- strheight(s1)
   sw1 <- strwidth(s1)
   sh2 <- strheight(s2)
   sw2 <- strwidth(s2)

   overlap <- FALSE
   if (x1<x2) 
     overlap <- x1 + sw1 > x2
   else
     overlap <- x2 + sw2 > x1

   if (y1<y2) 
     overlap <- overlap && (y1 +sh1>y2)
   else
     overlap <- overlap && (y2+sh2>y1)

   return(overlap)
}


draw_heatmap <- function(filename, plot_title, subset_name, taxa_count) {
   datamatrix<-read.table(filename, header=TRUE, row.names=1, sep="\t")

   subset_file_suffix = subset_name
   if ( subset_name == '?' ) {
      subset_file_suffix = 'misc'
   }
      

   if(subset_name != "all") {
      species_info <- get_species_info(datamatrix)
      #print(nrow(datamatrix))
      #print(species_info$point_symbols)
      colnums = sequence(ncol(datamatrix))
      subset_colnums = subset(colnums, species_info$point_symbols == subset_name)
      datamatrix = subset(datamatrix, select = subset_colnums) 
      #print(nrow(datamatrix))
   }


   # want to plot only the "taxa_count" most discriminatory taxa - i.e. 
   # 100 highest ranking standard deviations.
   # order the data by the stdev of each row (append the row stdevs 
   # as a column and sort on that)
   sdatamatrix <- cbind(datamatrix, rowSds(as.matrix(datamatrix)))
   #junk <- rowSds(as.matrix(datamatrix))
   sdatamatrix <- sdatamatrix[order(-sdatamatrix[,ncol(sdatamatrix)]),]
   sdatamatrix <- head(sdatamatrix, taxa_count)                    # take the first taxa_count
   sdatamatrix <- sdatamatrix[, sequence(ncol(sdatamatrix)-1)]   # drop the totals column


   # draw the heatmap in the usual way
   #cm<-brewer.pal(11,"Spectral") # a diverging palette
   cm<-brewer.pal(9,"OrRd") # a sequential palette 
   cm <- rev(cm)


   # set up a vector which will index the column labels that are to be blanked out so that 
   # only every nth col is labelled, 
   # the rest empty strings, n=col_label_interval.
   number_of_column_labels=ncol(sdatamatrix)
   col_label_interval=max(1, floor(ncol(sdatamatrix)/number_of_column_labels))  # 1=label every location 2=label every 2nd location  etc 
   colLabels <- colnames(sdatamatrix)
   colBlankSelector <- sequence(length(colLabels))
   colBlankSelector <- subset(colBlankSelector, colBlankSelector %% col_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)


   # set up a vector which will index the row labels that are to be blanked out so that 
   # only every nth col is labelled, 
   # the rest empty strings, n=col_label_interval.
   number_of_row_labels=taxa_count
   row_label_interval=max(1, floor(nrow(sdatamatrix)/number_of_row_labels))  # 1=label every location 2=label every 2nd location  etc 
   rowLabels <- rownames(sdatamatrix)
   rowBlankSelector <- sequence(length(rowLabels))
   rowBlankSelector <- subset(rowBlankSelector, rowBlankSelector %% row_label_interval != 0) 
                       # e.g. will get (2,3, 5,6, 8,9, ..)
                       # so we will only label rows 1,4,7,10,13 etc)


   # initial plot to get the column re-ordering
   jpeg(filename = "hm_internal.jpg" , width=830, height=1200) # with dendrograms

   hm<-heatmap.2(as.matrix(sdatamatrix),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/9*seq(0,11), 
       col = cm , key=FALSE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(17,28), cexRow=1.5, cexCol=1.8, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .6, 0 ), lhei=c(.5, 3))

  dev.off()


   # edit the re-ordered vectors of labels, obtained from the heatmap object, so that only 
   # every nth label on the final plot has a non-empty string
   # this is for the internal distance matrix
   indexSelector <- hm$colInd[length(hm$colInd):1]    
   indexSelector <- indexSelector[colBlankSelector]
   colLabels[indexSelector] = rep('',length(indexSelector))

   indexSelector <- hm$rowInd[length(hm$rowInd):1]    
   indexSelector <- indexSelector[rowBlankSelector]
   rowLabels[indexSelector] = rep('',length(indexSelector))

   jpeg(filename = paste("taxonomy_heatmap_", subset_file_suffix, ".jpg", sep=""), width=3000, height=2400) # with dendrograms
   hm<-heatmap.2(as.matrix(sdatamatrix),  scale = "none", 
       dendrogram = "col",  
       trace="none",
       #trace = "none", breaks =  -2 + 4/9*seq(0,11), 
       col = cm , key=FALSE, density.info="none", 
       #keysize=1.0, margin=c(17,25), cexRow=1.5, cexCol=1.6, 
       keysize=1.0, margin=c(27,28), cexRow=1.5, cexCol=1.3, 
       lmat=rbind(  c(4,3,0 ), c(2, 1, 0) ), lwid=c(.2, .6, 0 ), lhei=c(.25, 3),labCol=colLabels, labRow=rowLabels)
   title(paste(plot_title,"(", taxa_count, " most variable taxa across libraries)", sep=""),  cex.main=2.0)
   dev.off()

   clust = as.hclust(hm$colDendrogram)
   write.table(cutree(clust, 1:dim(sdatamatrix)[2]),file=paste("taxonomy_heatmap_", subset_file_suffix, "clusters.txt",sep=""), row.names=TRUE,sep="\t")  # ref https://stackoverflow.com/questions/18354501/how-to-get-member-of-clusters-from-rs-hclust-heatmap-2

}




plot_data<-function(filename, plot_title, save_prefix, cex_label, exclude_missing, highlight_this) {
   datamatrix<-read.table(filename, header=TRUE, row.names=1, sep="\t")
   clusters=get_clusters(datamatrix)

   if(exclude_missing) {
      fit_points = subset(clusters$fit$points, ! is.na(clusters$point_colours))
      point_symbols = subset(clusters$point_symbols, ! is.na(clusters$point_colours))
      sample_names = subset(clusters$sample_names, ! is.na(clusters$point_colours))
      point_colours = subset(clusters$point_colours, ! is.na(clusters$point_colours))
   }
   else {
      fit_points = clusters$fit$points 
      point_symbols = clusters$point_symbols
      sample_names = clusters$sample_names
      point_colours = clusters$point_colours
   }
   write.table(fit_points,file=paste(save_prefix,run_name,".txt",sep=""),row.names=TRUE,sep="\t")

   #print("symbols and colours")
   #print(point_symbols)
   #print(point_colours)
   cex_vector = rep( 1.2, length(point_symbols))
   if ( ! is.na(highlight_this) ){
      cex_vector = rep( 2.5, length(point_symbols))
      print(paste(" will highlight ", highlight_this, sep=" "))
      cex_selector=sequence(length(point_symbols))
      cex_selector = subset(cex_selector, point_symbols != highlight_this)
      cex_vector[cex_selector] <- 0.5

      print("samples selected:")
      print(subset(sample_names,  point_symbols == highlight_this))
      #print(cex_vector)
   }

   #plot.default(fit_points, col=point_colours, cex=1.5, pch=point_symbols)
   #plot.default(fit_points, col=point_colours, cex=1.5, pch=point_symbols, xlab="", ylab="", cex.axis=1.2, cex.lab=1.2)
   #plot.default(fit_points, col=point_colours, cex=1.5, pch=point_symbols, xlab="", ylab="", cex.axis=1.2, cex.lab=1.2)
   plot.default(fit_points, col=point_colours, cex=cex_vector , pch=point_symbols, xlab="", ylab="", cex.axis=1.2, cex.lab=1.2)

   #sample_names[1:(length(sample_names)-8)]<-NA
   sample_names[1:(length(sample_names)-24)]<-NA

   title(plot_title, cex.main=1.5)

   if ( ! is.na(highlight_this)) {
      return()
   }


   # this next block of code is to do with avoiding over-plotting the labels
   #text(clusters$fit$points, labels = clusters$sample_names, pos = 1, cex=1.5)
   #print(clusters$fit$points)
   #print(length( clusters$sample_names ))

   # we will look for label overlaps , and form the overlapping labels into groups, 
   # and label each group with just one of the labels. Then we will also
   # put up a key in the top left, with the definition of each group 
   # (There will be some placements of labels which will still result in over-plotting,
   # - can adjust the sensitivity/specificity of the overlap detection to handle this
   # (and also tolerate some over-plotting) )
   # this section defines the groups. . . . 
   plot_group_labels = vector("list", 0) 
   plot_group_pos = vector("list",0)
   for(i in 1:length( sample_names )) {
      if (! is.na(sample_names[i])) {
         if( length( plot_group_labels ) == 0 ) {
            plot_group_labels = c(plot_group_labels, sample_names[i])
            plot_group_pos = c(plot_group_pos,"") # need to be careful extending lists, to contain something that is itself a list(else you will flatten the new member)
            plot_group_pos[[length(plot_group_pos)]] = c( fit_points[i,1], fit_points[i,2] )
         }
         else {
            assigned_to_group = FALSE
            for(j in 1:length( plot_group_labels )) {
               # if this label overlaps a plot group , append the name to the group, and we assigned this label to a group 
               if(stroverlap( fit_points[i,1], fit_points[i,2] , sample_names[i],
                  plot_group_pos[[j]][1], plot_group_pos[[j]][2], plot_group_labels[[j]] )) {
                  plot_group_labels[[j]] = c( plot_group_labels[[j]] , sample_names[i]) 
                  assigned_to_group = TRUE
                  next   
               }
            } #for each plot group 
            if( ! assigned_to_group ) {
               # label did not overlap any groups so make a singleton for it
               plot_group_labels = c(plot_group_labels, sample_names[i])
               plot_group_pos = c(plot_group_pos,"") # need to be careful extending lists, to contain something that is itself a list(else you will flatten the new member)
               plot_group_pos[[length(plot_group_pos)]] = c( fit_points[i,1], fit_points[i,2] )
            } # not found 
         } # plot group has been initialiased
      } # if one of the labels we are to plot 
   } # for each point
   #print(plot_group_labels)
   #print(plot_group_pos)
                       

   #for(i in 1:length( clusters$sample_names )) {
   #   #print(clusters$fit$points[i])
   #   #print(clusters$sample_names[i])
   #   print(paste(clusters$fit$points[i,1], clusters$fit$points[i,2], clusters$sample_names[i]))
   #   text(clusters$fit$points[i,1], y=clusters$fit$points[i,2], labels = clusters$sample_names[i], pos = 4, cex=cex_label)
   #}


   # sort the plot group labels in descending order 
   for(i in 1:length( plot_group_labels )) {
       plot_group_labels[[i]] <- sort(plot_group_labels[[i]], decreasing=TRUE)
   }


   # label each "label-group" , with just one of the labels
   for(i in 1:length( plot_group_labels )) {
      if (length( plot_group_labels[[i]] ) ==1 ) {
         text(plot_group_pos[[i]][1], y=plot_group_pos[[i]][2], labels = plot_group_labels[[i]][1], adj=c(0,.5), cex=cex_label)
      }
      else {
         text(plot_group_pos[[i]][1], y=plot_group_pos[[i]][2], labels = paste(plot_group_labels[[i]][1], "(etc.)", sep=" "), adj=c(0,.5), cex=cex_label)
      }
   }


   # emit a key, defining the label groups (if there are any)
   top_left=c( 1.02 * min( fit_points[,1] ) , .98 * max( fit_points[,2] ) )
   key_row_count = 0
   for(i in 1:length( plot_group_labels )) {
      if (length( plot_group_labels[[i]] ) > 1 ) {
         key_name_string = paste(plot_group_labels[[i]][1], "(etc.) also includes nearby samples:", sep=" ")
         key_member_string = paste( plot_group_labels[[i]][2:length( plot_group_labels[[i]])], collapse=",")
         text(top_left[1] , y=top_left[2] - key_row_count * strheight(key_name_string) * 1.7, labels=key_name_string, cex=1.2, pos=4)
         key_row_count = key_row_count + 1
         text(top_left[1] , y=top_left[2] - key_row_count * strheight(key_member_string) * 1.7, labels=key_member_string, cex=1.2, pos=4)
         key_row_count = key_row_count + 1
      }
   }



   write.table(fit_points,file=paste(save_prefix,run_name,".txt",sep=""),row.names=TRUE,sep="\t")
}



detailed_heatmaps<-function() { 
   print("plotting fish")
   draw_heatmap("eukaryota_information.txt", "Fish Samples Taxonomy Overview", "F", 100) 
   print("plotting ryegrass")
   draw_heatmap("eukaryota_information.txt", "Ryegrass Samples Taxonomy Overview", "R", 100) 
   print("plotting mussel")
   draw_heatmap("eukaryota_information.txt", "Mussel Samples Taxonomy Overview", "M", 100) 
   print("plotting clover")
   draw_heatmap("eukaryota_information.txt", "Clover Samples Taxonomy Overview", "T", 100) 
   print("plotting deer")
   draw_heatmap("eukaryota_information.txt", "Deer Samples Taxonomy Overview", "D", 100) 
   print("plotting sheep")
   draw_heatmap("eukaryota_information.txt", "Sheep Samples Taxonomy Overview", "A", 100) 
   print("plotting goat")
   draw_heatmap("eukaryota_information.txt", "Goat Samples Taxonomy Overview", "G", 100) 
   print("plotting cattle")
   draw_heatmap("eukaryota_information.txt", "Cattle Samples Taxonomy Overview", "C", 100) 
   print("plotting seal")
   draw_heatmap("eukaryota_information.txt", "Seal Samples Taxonomy Overview", "S", 100) 
   print("plotting pea")
   draw_heatmap("eukaryota_information.txt", "Pea Samples Taxonomy Overview", "P", 100) 
   print("plotting weevil")
   draw_heatmap("eukaryota_information.txt", "Weevil Samples Taxonomy Overview", "W", 100) 
   print("plotting misc")
   draw_heatmap("eukaryota_information.txt", "Other Samples Taxonomy Overview", "?", 100) 
   #print("plotting endophyte")
   #draw_heatmap("eukaryota_information.txt", "Endophyte Samples Taxonomy Overview", "E", 100) 
}

overview<-function() {

   run_name<<-get_command_args()
   print("plotting overview")

   cex_label=1.0   # this setting used for doing just one of the plots
   jpeg(filename = paste("euk_taxonomy_clustering_",run_name,".jpg",sep=""), 800, 800) # this setting used for doing just one of the three plots below 
   plot_data("eukaryota_information.txt", "Clustering of Blast Eukaryota-Hit Profiles", "Clustering-of-Blast-Eukaryota-Hit-Profiles-", cex_label, TRUE, NA)
   dev.off()

   jpeg(filename = paste("all_taxonomy_clustering_",run_name,".jpg",sep=""), 800, 800) # this setting used for doing just one of the three plots below 
   plot_data("all_information.txt", "Clustering of Blast All-Hit Profiles", "Clustering-of-Blast-All-Hit-Profiles-", cex_label, TRUE, NA)
   dev.off()

   jpeg(filename = paste("xno_taxonomy_clustering_",run_name,".jpg",sep=""), 800, 800) # this setting used for doing just one of the three plots below 
   plot_data("all_information_xnohit.txt", "Clustering of Blast All-Hit Profiles (Excluding 'no hit')", "Clustering-of-Blast-All-Hit-Profiles-Excluding-no-hit-", cex_label, TRUE, NA)
   dev.off()
}

special<-function() {

   run_name<<-get_command_args()
   print("plotting overview")

   cex_label=1.0   # this setting used for doing just one of the plots
   jpeg(filename = paste("euk_taxonomy_clustering_",run_name,"_weevil.jpg",sep=""), 800, 800) # this setting used for doing just one of the three plots below
   plot_data("eukaryota_information.txt", "Clustering of Blast Eukaryota-Hit Profiles (highlighting weevil)", "Clustering-of-Blast-Eukaryota-Hit-Profiles-", cex_label, TRUE, 'W')
   dev.off()

}




detailed_heatmaps()
overview()

#special()



