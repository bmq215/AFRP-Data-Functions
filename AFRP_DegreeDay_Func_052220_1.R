
AFRP.degreeday = function(templogpath, water, depth, metric, tempthresh, minday = NA, maxday = NA)
{
  require(dplyr)
  require(data.table) #Necessary for fast reads; logger file too big for normal read.csv
  
  #Read in logger data
  templog = fread(templogpath, stringsAsFactors = F, na.strings = c("", "NA"))
  #templog[which(templog$TEMP_C == "NA"),]$TEMP_C = NA
 
  head(templog)
  #Subset and warn/exit if settings are wrong
  temp.sub = templog %>% filter(WATER == water)
  if(dim(temp.sub)[1] == 0){cat("Error: Water not found in data - exiting\n");return()}
  temp.sub = temp.sub %>% filter(METRIC == metric)
  if(dim(temp.sub)[1] == 0){cat("Error: Metric not found in data - exiting\n");return()}
  temp.sub = temp.sub %>% filter(DEPTH_M == depth)
  if(dim(temp.sub)[1] == 0)
  {
    cat("Error: Depth not found in data\n")
    cat(paste0("Available depths include: ",paste0(unique(templog[which(templog$WATER == water),]$DEPTH_M), collapse = ", ")
               ,"\nExiting\n"))
    return()
  }
  if(!is.na(minday))
  {
    temp.sub = temp.sub %>% filter(DAY_N >= minday)
  }
  if(!is.na(maxday))
  {
    temp.sub = temp.sub %>% filter(DAY_N <= maxday)
  }
  if(dim(temp.sub)[1] == 0){cat("Error: No records within day limits - exiting\n");return()}
  
  #Let's make sure that there aren't gaps in the record...
  check = temp.sub %>% group_by(YEAR, LOCATION, SITE) %>% 
    summarize(minday= min(DAY_N), maxday = max(DAY_N),DAYSRECORDED = length(unique(DAY_N)))
  check$MaxMin = (check$maxday +1) - check$minday
  check$Disrep = check$MaxMin - check$DAYSRECORDED
  check = check[which(check$Disrep > 0 ),]
  if(dim(check)[1] > 0)
  {
    cat("Warning: Measurements are not continuous for some years\n\n")
    print(data.frame(Year = check$YEAR, RecordInterval = check$MaxMin, RecordN = check$DAYSRECORDED, Difference = check$Disrep), 
          row.names = F)
    cat("\n")
  }
  
  #Calculate degree days and TU
  temp.sub$TEMPTHRESH = tempthresh
  temp.sub$AtAboveThresh = as.numeric(as.numeric(temp.sub$TEMP_C) > tempthresh)
  temp.sub$DegreeDay = (as.numeric(temp.sub$TEMP_C) - tempthresh) * temp.sub$AtAboveThresh
  temp.sub$TU = as.numeric(temp.sub$TEMP_C)
  
  #Summarize by year and output
  Out = temp.sub %>% group_by(YEAR, LOCATION, SITE) %>% 
    summarize(WATER = first(WATER), DEPTH_M = first(DEPTH_M), METRIC = first(METRIC),
              TEMPTHRESH = first(TEMPTHRESH), DAYSRECORDED = length(unique(DAY_N)), DEGREEDAYS = sum(DegreeDay), TU = sum(TU))
  if(sum(as.numeric(is.na(Out$DEGREEDAYS)))>0){cat("Warning: NAs in data prevented calculation for some years\n")}
  cat("Done\n")
  return(Out)

}




       