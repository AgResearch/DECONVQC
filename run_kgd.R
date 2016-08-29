print("in run_kgd.R")
print("args  :")
args = commandArgs(trailingOnly=TRUE)
print(args[1])


gform <- "uneak"
#genofile <- "/dataset/MBIE_genomics4production/scratch/deer_comparison/UNEAK/hapMap/HapMap.hmc.txt"
genofile <- args[1]
source(file.path(Sys.getenv("GBS_BIN"),"GBS-Chip-Gmatrix.R"))
Gfull <- calcG()
GHWdgm.05 <- calcG(which(HWdis > -0.05),"HWdgm.05", npc=4)  # recalculate using Hardy-Weinberg disequilibrium cut-off at -0.05
