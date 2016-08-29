# 
#-------------------------------------------------------------------------
# make plots from tag count summaries by sample, which look like this:
#flowcell_sq     mean_tag_count  std_tag_count   min_tag_count   max_tag_count   mean_read_count std_read_count  min_read_count  max_read_count
#C6JPMANXX_SQ2520        976472.615789   212668.620496   3830    1599219 2132386.21579   630334.301231   4597    4279822
#C6JPMANXX_88    387122.873684   147743.752255   97951   690903  2132244.45263   1326778.91643   289705  5401544
#C6JPMANXX_SQ2519        311309.849462   94510.8959621   74503   848145  2447598.47312   1058499.5325    321593  8813864
#C6JPMANXX_89    284845.515789   75243.8301209   90670   424635  2154863.72632   1082929.26321   233966  4767725
#
#-------------------------------------------------------------------------


data_folder="/dataset/hiseq/scratch/postprocessing/"     
output_folder="/dataset/hiseq/scratch/postprocessing/" 
input_file="all_tag_count_summaries.txt"  


draw_plots <- function(reads_tags, tag_data, point_labels, number_of_recent_samples) {
   if(reads_tags == "tags" ) {
      jpeg(filename = "tags_summary.jpg", 1600,1600)
      par(mfrow=c(2,2))
      plot(tag_data$mean_tag_count,tag_data$std_tag_count, main="Tag counts by sample:mean,stddev", xlab="Mean", ylab="Standard Deviation", cex=2.0, cex.lab=1.9, cex.main=1.9)  
      text(tag_data$mean_tag_count,tag_data$std_tag_count,labels=point_labels, cex=1.2, adj = c( 0, 1 ))                                                   

      xmin <- par("usr")[1]
      xmax <- par("usr")[2]
      ymin <- par("usr")[3]
      ymax <- par("usr")[4]
      delta_y=(ymax-ymin)/40.0
      delta_x=(xmax-xmin)/8


      for(offset_from_last in sequence(number_of_recent_samples)-1 ) {
         data_row = nrow(tag_data) - (number_of_recent_samples-1-offset_from_last)
         cv = round(100 * tag_data$std_tag_count[data_row] / tag_data$mean_tag_count[data_row], 2)
         annotation = paste(tag_data$flowcell_sq[data_row], " CV (stddev/mean %)= ", as.character(cv))
         text( xmin + delta_x , ymax - delta_y * (1+offset_from_last), annotation, cex=1.5 , adj = c( 0, 1 ))
      }

      plot(tag_data$mean_tag_count,tag_data$max_tag_count, main="Tag counts by sample:mean,max", xlab="Mean", ylab="Max", cex=2.0, cex.lab=1.9, cex.main=1.9)  
      text(tag_data$mean_tag_count,tag_data$max_tag_count,labels=point_labels, cex=1.2, adj = c( 0, 1 ))                                                   

      plot(tag_data$mean_tag_count,tag_data$min_tag_count, main="Tag counts by sample:mean,min", xlab="Mean", ylab="Min", cex=2.0, cex.lab=1.9, cex.main=1.9)  
      text(tag_data$mean_tag_count,tag_data$min_tag_count,labels=point_labels, cex=1.2, adj = c( 0, 1 ))                                                   
   }
   else if(reads_tags == "reads") {
      jpeg(filename = "read_summary.jpg", 1600,1600)
      par(mfrow=c(2,2))
      plot(tag_data$mean_read_count,tag_data$std_read_count, main="Read counts by sample:mean,stddev", xlab="Mean", ylab="Standard Deviation", cex=2.0, cex.lab=1.9, cex.main=1.9)  
      text(tag_data$mean_read_count,tag_data$std_read_count,labels=point_labels, cex=1.2, adj = c( 0, 1 ))                                                   

      xmin <- par("usr")[1]
      xmax <- par("usr")[2]
      ymin <- par("usr")[3]
      ymax <- par("usr")[4]
      delta_y=(ymax-ymin)/40.0
      delta_x=(xmax-xmin)/8


      for(offset_from_last in sequence(number_of_recent_samples)-1 ) {
         data_row = nrow(tag_data) - (number_of_recent_samples-1-offset_from_last)
         cv = round(100 * tag_data$std_read_count[data_row] / tag_data$mean_read_count[data_row], 2)
         annotation = paste(tag_data$flowcell_sq[data_row], " CV (stddev/mean %)= ", as.character(cv))
         text( xmin + delta_x , ymax - delta_y * (1+offset_from_last), annotation, cex=1.5 , adj = c( 0, 1 ))
      }

      plot(tag_data$mean_read_count,tag_data$max_read_count, main="Read counts by sample:mean,max", xlab="Mean", ylab="Max", cex=2.0, cex.lab=1.9, cex.main=1.9)  
      text(tag_data$mean_read_count,tag_data$max_read_count,labels=point_labels, cex=1.2, adj = c( 0, 1 ))                                                   

      plot(tag_data$mean_read_count,tag_data$min_read_count, main="Read counts by sample:mean,min", xlab="Mean", ylab="Min", cex=2.0, cex.lab=1.9, cex.main=1.9)  
      text(tag_data$mean_read_count,tag_data$min_read_count,labels=point_labels, cex=1.2, adj = c( 0, 1 ))                                                   
   }
   else {
      print("Error - unknown plot type")
   }

   dev.off()
}


main <- function(number_of_recent_samples) {
   # read data
   setwd(data_folder)
   tag_data = read.table(input_file, header=TRUE, sep="\t")
   point_labels=tag_data$flowcell_sq
   point_labels[1:(length(point_labels)-number_of_recent_samples)]<-NA   # we only label the lanes from the latest run

   draw_plots("tags", tag_data, point_labels, number_of_recent_samples)
   draw_plots("reads", tag_data, point_labels, number_of_recent_samples)
}
main(8)










