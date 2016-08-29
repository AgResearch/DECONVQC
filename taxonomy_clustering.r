# 
setwd("/dataset/hiseq/scratch/postprocessing/")

get_clusters <- function(datamatrix) {
   num_clust=20   # all 
   num_clust=20   # euk only
   clustering <- kmeans(datamatrix, num_clust, iter.max=500)
   tcenters=t(clustering$centers)
   distances <- dist(tcenters)
   sample_species_table<-read.table("sample_species.txt", header=TRUE, row.names=1, sep="\t")
   species_config_table<-read.table("species_config.txt", header=TRUE, row.names=1, sep="\t")
   sample_names <- strsplit(rownames(t(datamatrix)), split="_")
   get_name <- function(split_result) unlist(split_result)[6]
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
   for(rowname in rownames(species_config_table)) {
      regexp <-  toString(species_config_table[rowname, "regexp"])
      colour <- paste("#", toString(species_config_table[rowname, "colour"]),sep="")
      symbol <- toString(species_config_table[rowname, "symbol"]) 
      point_colours[ grep(regexp,species_names, ignore.case = TRUE) ] <- colour
      point_symbols[ grep(regexp,species_names, ignore.case = TRUE) ] <- symbol
   }

   distances = dist(as.matrix(t(datamatrix)))

   fit <- cmdscale(distances,eig=TRUE, k=2)

   results=list()
   results$fit = fit
   results$point_symbols = point_symbols
   results$point_colours = point_colours
   results$sample_names = sample_names

   return(results)
}

jpeg(filename = "taxonomy_clustering.jpg", 800, 1600)
par(mfrow=c(2, 1))


datamatrix<-read.table("eukaryota_information.txt", header=TRUE, row.names=1, sep="\t")
clusters=get_clusters(datamatrix)
plot.default(clusters$fit$points, col=clusters$point_colours, cex=1.5, pch=clusters$point_symbols)
clusters$sample_names[1:(length(clusters$sample_names)-8)]<-NA
title("Clustering of Blast Eukaryota-Hit Profiles")
text(clusters$fit$points, labels = clusters$sample_names, pos = 1, cex=0.8)


datamatrix<-read.table("all_information.txt", header=TRUE, row.names=1, sep="\t")
clusters=get_clusters(datamatrix)
plot.default(clusters$fit$points, col=clusters$point_colours, cex=1.5, pch=clusters$point_symbols)
clusters$sample_names[1:(length(clusters$sample_names)-8)]<-NA
title("Clustering of Blast All-Hit Profiles")
title("Clustering of Blast All-Hit Profiles")
text(clusters$fit$points, labels = clusters$sample_names, pos = 1, cex=0.8)

dev.off()


