#Function to interpolate AFRP temperature and oxygen profiles
#Takes a water name and .csv inputs to the two database tables (MEASUREMENT and SAMPLE)
#Returns data.frame with estimates of the temp and oxy within the data's range of dates and depths
#Rounding (for averages) and interpolation resolution can be set if desired
#Also includes provisions for min/max limitations on the dates used

#Ben MQ - 5/12/2020

AFRP.tempoxy = function(water, samp, meas,  
                        depthround = 1, dateround = 30, depthres = 0.25, dateres = 1,badsamps = NA,
                        monthmin = NA, monthmax = NA, yearmin = NA, yearmax = NA, interpdates = T)
{
  # Setup ----
  library(dplyr)

  #Read in data
  cat("Reading in data...\n")
  wcs.samp = read.csv(samp, stringsAsFactors = F)
  wcs.meas = read.csv(meas, stringsAsFactors = F)

  
  #Join by YSAMP
  wcs = wcs.samp %>% right_join(wcs.meas, by = "YSAMP_N")
  
  #Cut down to just the water of interest
  wcs.sub = wcs %>% filter(WATER == water)

  #If there are any limits to the date range, subset to that
  if(!is.na(monthmin))
  {
    wcs.sub = wcs.sub %>% filter(MONTH >= monthmin)
  }
  if(!is.na(monthmax))
  {
    wcs.sub = wcs.sub %>% filter(MONTH <= monthmax)
  }
  if(!is.na(yearmin))
  {
    wcs.sub = wcs.sub %>% filter(YEAR >= yearmin)
  }
  if(!is.na(yearmax))
  {
    wcs.sub = wcs.sub %>% filter(YEAR <= yearmax)
  }
  
  #If there are any bad samples listed, filter those out
  if(!is.na(badsamps))
  {
    wcs = wcs[which(!(wcs$YSAMP_N %in% badsamps)),]
  }
  unique(wcs.sub$DAY_N)
  
  #Also remove any measurements without a value
  wcs.sub =  wcs.sub[which(!is.na(wcs.sub$VALUE_1)),]
  
  #Order measurements by depth and round to desired value 
  wcs.sub = wcs.sub[order(wcs.sub$DEPTH_M),]
  wcs.sub$DEPTHROUND = (round(wcs.sub$DEPTH_M/depthround)*depthround)

  #Aggregate by desired date interval
  wcs.sub$DateInt = ((floor(wcs.sub$DAY_N/dateround))*dateround)
  
  
  #If you only want depth interpolation, replace that with simple dates
  if(!interpdates)
  {
    wcs.sub$DateInt = wcs.sub$DATE_COL
  }
  
  #Clear out NAs
  wcs.sub = wcs.sub[which(!is.na(wcs.sub$DateInt)),]
  
  #Filter out temp and oxy components
  wcs.sub.T = wcs.sub %>% filter(METRIC == "WATER TEMPERATURE") %>% group_by(WATER, DateInt, DEPTHROUND) %>% summarize(N = n(), meanTemp = median(VALUE_1),medTemp = median(VALUE_1), sdTemp = sd(VALUE_1))
  wcs.sub.O = wcs.sub %>% filter(METRIC == "DISSOLVED OXYGEN") %>% group_by(WATER, DateInt, DEPTHROUND) %>% summarize(N = n(), meanOxy = median(VALUE_1),medOxy = median(VALUE_1), sdOxy = sd(VALUE_1))
  wcs.sub.T = wcs.sub.T %>% filter(!is.na(meanTemp))
  wcs.sub.O = wcs.sub.O %>% filter(!is.na(meanOxy))
  
  #Set up output holding variables
  wcs.temp.T = NULL
  wcs.temp.O = NULL

  cat("Interpolating between depths...\n")
  #Loop through date intervals and interpolate between depths
  for(j in unique(wcs.sub.T$DateInt))
  {
    #Set min and max depths
    mindepth = 0
    maxdepth = min(max(wcs.sub.T$DEPTHROUND, na.rm = T),max(wcs.sub.O$DEPTHROUND, na.rm = T))
    
    #Subset by date
    wcs.dateint.T = wcs.sub.T %>% filter(DateInt == j)
    wcs.dateint.O = wcs.sub.O %>% filter(DateInt == j)
    
    #Exit if there isn't enough temp data
    if(dim(wcs.dateint.T)[1] < 5 || (maxdepth - max(wcs.dateint.T$DEPTHROUND, na.rm = T)) > 10){ next}
    #Interpolate temperatures between depths
    interp.T = approx(wcs.dateint.T$DEPTHROUND,wcs.dateint.T$meanTemp, xout = seq(0,maxdepth,by = depthres), rule = 2)
    wcs.temp.T = rbind(wcs.temp.T, data.frame(WATER = water, DateInt = j, DEPTHROUND = interp.T$x, ValEst = interp.T$y))
    
    #Exit if there isn't enough oxygen data
    if(dim(wcs.dateint.O)[1] < 5 || (maxdepth - max(wcs.dateint.O$DEPTHROUND, na.rm = T)) > 10){ next}
    #Interpolate oxygen concentrations between depths
    interp.O = approx(wcs.dateint.O$DEPTHROUND,wcs.dateint.O$meanOxy, xout = seq(0,maxdepth,by = depthres), rule = 2)
    wcs.temp.O = rbind(wcs.temp.O, data.frame(WATER = water, DateInt = j, DEPTHROUND = interp.O$x, ValEst = interp.O$y))
  }

  #Set up output holding variables
  wcs.grid = NULL 
  
  #If interpolation between dates is desired (e.g. you want a generalized profile throughout the sampling range)
  if(interpdates)
  {
    cat("Interpolating between dates...\n")
    #Loop through depth intervals and interpolate between dates
    for(k in unique(wcs.temp.T$DEPTHROUND))
    {
  
      wcs.depth.T = wcs.temp.T %>% filter(DEPTHROUND == k)
      wcs.depth.O = wcs.temp.O %>% filter(DEPTHROUND == k)
      
      #Get min and max
      mindateint = min(wcs.depth.T$DateInt)
      maxdateint = max(wcs.depth.T$DateInt)
      
      #Interpolate temperatures and oxygen concentrations
      interp.T = approx(wcs.depth.T$DateInt,wcs.depth.T$ValEst, xout = seq(mindateint, maxdateint,by = dateres))
      interp.O = approx(wcs.depth.O$DateInt,wcs.depth.O$ValEst, xout = seq(mindateint, maxdateint,by = dateres))
  
  
      #if(dim(wcs.depth.O)[1] < 5){next}
      #interp.O = approx(wcs.depth.O$DateInt,wcs.depth.O$ValEst, xout = seq(mindateint, maxdateint,by = dateres))
      #interp.T = spline(wcs.depth.T$WEEK,wcs.depth.T$ValEst, xout = seq(minmonth, maxmonth,by = monthres))
      #interp.O = spline(wcs.depth.O$WEEK,wcs.depth.O$ValEst, xout = seq(minmonth, maxmonth,by = monthres))
      
      #Bind together outputs
  
      wcs.grid = rbind(wcs.grid, data.frame(Water = water, Date = interp.T$x, Depth = k, TempEst = interp.T$y,OxyEst = interp.O$y))
    }
  } else {
    
    cat("Date interpolation disabled, returning individual profiles...\n")
    
    #Format and join temp/oxy depth interpolations
    wcs.temp.O$DateInt = as.character(wcs.temp.O$DateInt )
    wcs.temp.T$DateInt = as.character(wcs.temp.T$DateInt )
    wcs.grid = data.frame(Water = water, Date = wcs.temp.T$DateInt, Depth = wcs.temp.T$DEPTHROUND, TempEst = wcs.temp.T$ValEst, stringsAsFactors = F)
    wcs.grid = wcs.grid %>% left_join(select(wcs.temp.O,c("DateInt","DEPTHROUND", "ValEst")) , by = c("Date" = "DateInt", "Depth" = "DEPTHROUND"))
    colnames(wcs.grid)[which(colnames(wcs.grid) == "ValEst")] = "OxyEst"
    
  }
  
  cat("Done\n")
  return(wcs.grid)
}
  