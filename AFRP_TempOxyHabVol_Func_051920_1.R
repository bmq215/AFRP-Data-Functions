

AFRP.habvol = function(TempOxy,DepthData, minoxy, maxtemp)
{
  # Setup ----
  library(dplyr)
  
  #Get unique dates and depth range
  dates = unique(TempOxy$Date)
  depthmin = min(TempOxy$Depth, na.rm = T)
  depthmax = max(TempOxy$Depth, na.rm = T)
  
  #Determine water
  water = unique(TempOxy$Water)[1]
  cat(paste0("Detected temperature/oxygen data for: ",water,"\n"))
  
  
  #Determine depth resolution of temperature and oxygen info
  tempdepths = sort(unique(TempOxy$Depth))
  tempdepthdelts = tempdepths[2:length(tempdepths)] - tempdepths[1:(length(tempdepths)-1)]
  tempdepthres = mean(tempdepthdelts)
  if(tempdepthres != tempdepthdelts[1]){ cat("Warning: temp/oxy dataset contains irregular intervals") }
  
  #Load depth data
  Depths = read.csv(DepthData, stringsAsFactors = F)
  
  #Subset by water
  if(!(water %in% Depths$Water))
  {
    cat("No depth data for chosen water - exiting.\n")
    return()
  }
  Depths = Depths[which(Depths$Water == water),]
  head(Depths)
  
  #Determine resolution of depth data
  voldepths = sort(unique(Depths$Depth_m))
  voldepthdelts = voldepths[2:length(voldepths)] - voldepths[1:(length(voldepths)-1)]
  voldepthres = mean(voldepthdelts)
  if(voldepthres != voldepthdelts[1]){ cat("Warning: depth dataset contains irregular intervals") }
  
  #Figure out whichever one is larger and downsample the other to that resolution
  if(voldepthres == tempdepthres)
  {
    cat(paste0("Resolution of both datasets equal (",round(voldepthres,3),") proceeding...\n"))
    combdepthres = tempdepthres
  } else if(voldepthres < tempdepthres)
  {
    cat(paste0("Resolution of volume (",round(voldepthres,3),") finer than temp/oxy (",round(tempdepthres,3),") downsampling volume...\n"))
    Depths$DownSamp = round(Depths$Depth_m / tempdepthres,0) * tempdepthres
    Depths = Depths %>% group_by(Water, DownSamp) %>% summarize(Count = sum(Count))
    colnames(Depths)[which(colnames(Depths) == "DownSamp")] = "Depth_m"
    combdepthres = tempdepthres
  } else if(voldepthres > tempdepthres)
  {
    cat(paste0("Resolution of temp/oxy (",round(tempdepthres,3),") finer than volume (",round(voldepthres,3),") downsampling temp/oxy...\n"))
    TempOxy$DownSamp = round(TempOxy$Depth / voldepthres,0) * voldepthres
    TempOxy = TempOxy %>% group_by(Water, DownSamp, Date) %>% summarize(TempEst = mean(TempEst, na.rm = T), OxyEst = mean(OxyEst, na.rm = T))
    colnames(TempOxy)[which(colnames(TempOxy) == "DownSamp")] = "Depth"
    combdepthres = voldepthres
  }
  
  #Determine suitability
  TempOxy$TempSuit = TempOxy$TempEst <= maxtemp
  TempOxy$OxySuit = TempOxy$OxyEst >= minoxy
  TempOxy$CombSuit = TempOxy$TempSuit & TempOxy$OxySuit
  
  #Set up volume placeholders
  TempOxy$VolSuitTemp = 0
  TempOxy$VolSuitOxy = 0
  TempOxy$VolSuitComb = 0
  TempOxy.hold = NULL
  #Loop through dates
  for(i in seq(length(dates)))
  {
    TempOxy.sub = TempOxy %>% filter(Date == dates[i])
    cat(paste0("\rProcessing dates (",i," out of ", length(dates),")" ))

    for(j in sort(unique(TempOxy.sub$Depth)))
    {
      if(j == 0){ next}
      #If temperature is suitable at that depth, determine the volume
      if(!is.na(TempOxy.sub[which(TempOxy.sub$Depth == j),]$TempSuit[1]) && TempOxy.sub[which(TempOxy.sub$Depth == j),]$TempSuit[1])
      {
        TempOxy.sub[which(TempOxy.sub$Depth == j),]$VolSuitTemp =  sum(Depths[which(Depths$Depth_m >= j),]$Count) * combdepthres 
      }
      #If oxygen is suitable at that depth, determine the volume
      if(!is.na(TempOxy.sub[which(TempOxy.sub$Depth == j),]$OxySuit[1]) && TempOxy.sub[which(TempOxy.sub$Depth == j),]$OxySuit[1])
      {
        TempOxy.sub[which(TempOxy.sub$Depth == j),]$VolSuitOxy = sum(Depths[which(Depths$Depth_m >= j),]$Count) * combdepthres 
      }
      #If both are suitable at that depth, determine the volume
      if(!is.na(TempOxy.sub[which(TempOxy.sub$Depth == j),]$CombSuit[1]) && TempOxy.sub[which(TempOxy.sub$Depth == j),]$CombSuit[1])
      {
        TempOxy.sub[which(TempOxy.sub$Depth == j),]$VolSuitComb = sum(Depths[which(Depths$Depth_m >= j),]$Count) * combdepthres 
      }
    }
    
    #Add back to main set
    rows.hold = which(TempOxy$Date == dates[i])
    #TempOxy[which(TempOxy$Date == dates[i]),c("VolSuitTemp","VolSuitOxy","VolSuitComb")] = TempOxy.sub[,c("VolSuitTemp","VolSuitOxy","VolSuitComb")]
    TempOxy[rows.hold,]$VolSuitTemp = TempOxy.sub$VolSuitTemp
    TempOxy[rows.hold,]$VolSuitOxy = TempOxy.sub$VolSuitOxy
    TempOxy[rows.hold,]$VolSuitComb = TempOxy.sub$VolSuitComb
    
  }
  cat("\n")

  #Go back and stick in NAs if the readings were actually NAs
  if(sum(is.na(TempOxy$TempEst))>0){  TempOxy[which(is.na(TempOxy$TempEst)),]$VolSuitTemp = NA}
  if(sum(is.na(TempOxy$OxyEst))>0){  TempOxy[which(is.na(TempOxy$OxyEst)),]$VolSuitOxy = NA}
  if(sum(is.na(TempOxy$TempEst) | is.na(TempOxy$OxyEst))>0){TempOxy[which(is.na(TempOxy$TempEst) | is.na(TempOxy$OxyEst)),]$VolSuitComb = NA}

  TempOxyVol = TempOxy %>% group_by(Water, Date) %>% summarize(VolSuitTemp = sum(VolSuitTemp),VolSuitOxy = sum(VolSuitOxy),VolSuitComb = sum(VolSuitComb))
  
  #Calculate total volume
  TotVol = sum(Depths$Count * Depths$Depth_m)
  
  #Adjust total volume for minor rounding issues
  MaxVolRatio = (TotVol- max(c(TempOxyVol$VolSuitTemp,TempOxyVol$VolSuitOxy), na.rm = T))/ TotVol
  if(MaxVolRatio < 0 & MaxVolRatio > -.1)
  {
    TotVol = max(c(TempOxyVol$VolSuitTemp,TempOxyVol$VolSuitOxy), na.rm = T) 
  } else if(MaxVolRatio < 0 & MaxVolRatio <= -.1)
  {
    cat(paste0("Warning: Max volume of suitable habitat greater than max volume of lake (by ", abs(round(MaxVolRatio,2))*100,"%) - error in depth code?\n"))
  }
  
  #Calculate percentages
  TempOxyVol$PropSuitTemp = TempOxyVol$VolSuitTemp / TotVol
  TempOxyVol$PropSuitOxy = TempOxyVol$VolSuitOxy / TotVol
  TempOxyVol$PropSuitComb = TempOxyVol$VolSuitComb / TotVol
  
  TempOxyVol$TotVol = TotVol
  
  return(TempOxyVol)
}

