# AFRP-Data-Functions
Functions for cleaning, manipulating, and analyzing AFRP data.

## AFRP.tempoxy

Interpolation function for temperature/oxygen profiles from the AFRP water chemistry database

### Usage

>AFRP.tempoxy(water, samp, meas, depthround = 1, dateround = 30, depthres = 0.25, dateres = 1,badsamps = NA, monthmin = NA, monthmax = NA, yearmin = NA, yearmax = NA, interpdates = T)

### Arguments
 
* **water**	 - character vector designating which water to examine. Must be in the same format as the “samp” table. Currently this is the legacy all-caps no-abbreviations format (e.g. “LITTLE MOOSE LAKE”)

* **samp, meas** -character vectors denoting the path to comma-separated files for the two water chemistry tables

* **depthround** - depth increment by which to condense and summarize depth readings

* **dateround**	- date increment by which to condense and summarize sampling events

* **depthres** -	depth resolution for interpolation. Output data will be in increments of this value

* **dateres** -	date resolution for interpolation. Output data will be in increments of this value

* **badsamps** -	vector of strings denoting YSAMP_Ns that should be skipped. Useful for avoiding events with spurious values. Will be ignored if set to NA (default)

* **monthmin, monthmax** -	alues for the minimum and maximum months to consider. Inputs should be in range 1:12. Will be ignored if set to NA (default)

* **yearmin, yearmax** - values for the minimum and maximum months to consider. Inputs should be four digit years (e.g. 2001). Will be ignored if set to NA (default)
interpdates	Boolean variable determining whether interpolation between dates is desired. If set to FALSE will only perform interpolation between depths. Output data will have regularly spaced depths equal to “depthres” but estimates will only be for sampling dates in the database. In addition, returned dates will be character values from the database rather than ordinal days.
 

### Details
This function uses the AFRP water chemistry database and performs a variable amount of summarization and interpolation depending on the available data and settings. Upon being run, the function loads .csv files for both tables from the water chemistry database (“sample” and “measurement”). It then joins the two tables by YSAMP_N and filters all but the specific water of interest using functions from the dplyr package.

Next, depth readings are rounded to the nearest value set by depthround. E.g. if depthround = 1, a reading for 1.5m will be rounded to 2m. If depthround = 0.25, a reading of 0.5m will remain untouched. Ordinal dates (DAY_N) for each sampling event are then similarly rounded into discrete X-day categories where X is set by dateround. Thus if dateround = 30, the ordinal date of each sampling event will be rounded to the nearest 30 day category (counting from the beginning of the year). However, if interpdate = F this step will be skipped and the date value used for further analysis will be set to the DATE_COL from the sample file.

Measurements of temperature and oxygen for each combination of rounded depth and date category are then averaged. For example, if depthround = 1 and dateround = 30, measurements taken at 1.5 and 2.0m deep during May over a period of five years would be averaged to a single value. When interpdate = F, however, averaging only takes place for rounded depths on each specific date (e.g. the previous example would average values for 1.5 and 2.0m together, but would yield a separate value for each year).

Linear interpolation is then used to ensure smooth profiles for each date category (either X-day chunk or discrete sampling event if interpdates = F). This is done using the approxfun() in concert with the averaged temperature and oxygen concentrations for each depth and returns a regularly-spaced profile with increments set by depthres.

If interpdates = F, the function is now complete and returns results of the depth averaging and interpolation. However, if interpdates = T (default) the function now performs a second round of interpolation. For each regular depth increment, the estimated values are then interpolated across the range of available dates, returning estimates for each increment of dateres. The doubly-interpolated values are then return. This results in a dataset with regular spacing in two dimensions, suitable for plotting average profiles throughout the season for a given lake.

### Value
AFRP.tempoxy returns a data frame with components Water, Date, Depth, TempEst, and OxyEst. Date is either a numeric ordinal date (if interpdates = T) or a MM/DD/YYYY character vector (if interpdates = F).

### Example
```
#Provide data location
samp = "C:\\Users\\Ben\\Desktop\\Data\\WCS_SAMPLE_050420.txt"
meas = "C:\\Users\\Ben\\Desktop\\Data\\WCS_MEASUREMENT_050420.txt"

#Choose water
water = "WILMURT LAKE"

#Run function
TempOxy = AFRP.tempoxy(water, samp, meas, dateres = 1, yearmin = 2000)
head(TempOxy)
```

## AFRP.habvol

Calculate habitat volumes within temperature and oxygen limits from profiles and hypsographic curves.

### Usage

>AFRP.habvol(TempOxy, DepthData, minoxy, maxtemp)

### Arguments
 
* **TempOxy** - data frame with components Water, Date, Depth, TempEst, and OxyEst. Date can either a numeric or character vector. Values for both Water and Date will simply be passed along to the results. TempEst and OxyEst can contain NAs. The AFRP.tempoxy function will automatically produce a data frame with the correct format

* **DepthData** -	character vector denoting the path to a comma-separated table with hypsographic curves for AFRP waters. Must contain the fields “Water”, “Depth_m”, and “count”. Water names must match those in the TempOxy input. The XY resolution of the data is assumed to be one meter.

* **minoxy** -minimum habitable oxygen concentration

* **maxtemp** -	maximum habitable temperature

 

### Details

This calculates the volume and proportion of suitable habitat in a lake based on temperature/oxygen profiles. Depth- and date-specific temperature and oxygen values are required as input, as are hypsographic information for the particular water and temperature/oxygen limitations.

First the DepthData .csv is loaded. Then the water in the TempOxy dataset is detected and entries in DepthData that do not pertain to that water are filtered out. The relative depth resolutions for both data frames are calculated. If either dataset has irregular spacing (i.e. skipped values or shifts in measurement frequency) a warning will be given. Irregular datasets will likely return spurious estimates. If the two datasets have different resolutions the finer-scale data will be downsampled to match the other. This is achieved by rounding the depth values for that dataset to the nearest increment of the coarser resolution and then calculating the mean for each rounded depth increment. The function will report when this is being done.

Next the temperature and oxygen values for each row in the TempOxy dataset are compared to the provided limitations and determined to be either TRUE (suitable) or FALSE (unsuitable). A nested loop then runs through each date and depth from the TempOxy dataset. If the suitability value for the given date and depth combination is TRUE, the volume of that layer is calculated. This is done by selecting the rows in the DepthData dataset that are equal to or deeper than the depth value under consideration, summing the “count” values for those rows (i.e. the number of cells), and then multiplying that number by the depth resolution. If the suitability value for the given data and depth combination is FALSE (unsuitable) the volume is set to zero. This is done until each depth on each date has either a volume or a zero. These calculations are done three times, once for temperature suitability, once for oxygen, and once for the two combined. Dates for which either the temperature or oxygen values contain an NA value have their volume set to NA.

Finally the calculated volumes (and zeros) for each suitability criteria are summed by date using functions from the dplyr package. These sums are further divided by the total volume of the water (calculated from the DepthData dataset) in order to report proportional values. The results for each data and criteria are returned as a data frame.

### Value
AFRP.habvol returns a data frame with components Water, Date, VolSuitTemp, VolSuitOxy, VolSuitComb, PropSuitTemp. PropSuitOxy, PropSuitComb, and TotVol. Water is used to select the correct depth data and will contain a single value. Date is used for grouping data and will be in the format initially provided with the TempOxy input. Each “VolSuit…” column contains the volume of suitable habitat for temperature, oxygen, and the two combined, respectively. Similarly, the three “PropSuit…” columns contain those values transformed to proportions. Finally the TotVol column contains the calculated total volume of the water and will have a single value for the entire data frame.

### Example
```
#Provide location for depth data
DepthData = "C:\\Users\\Ben\\Google Drive\\Research\\AFRP Misc\\Lake Volumes\\AFRP_Waters_DepthCellCounts_Cm_3.csv"

#Set temp/oxy proferences
minoxy = 6.3 #Stressful for brook trout (Raleigh 1982, Robinson 2010)
maxtemp = 20 #Stressful for brook trout (Raleigh 1982)

#Run function
TempOxyVol = AFRP.habvol(TempOxy, DepthData, minoxy, maxtemp)
head(TempOxyVol)
```

## AFRP.degreeday
Calculate degree days i.e. cumulative degrees above a provided temperature threshold each year for a given water and depth. Designed to use the AFRP temperature logger dataset in its spring 2020 redesigned, single-file format. Also calculates temperature units (TU) i.e. cumulative degrees above 0°C for the given water and depth.

### Usage
>AFRP.degreeday(templogpath, water, depth, metric, tempthresh, minday = NA, maxday = NA)

### Arguments
 
* **templogpath** -	character vector denoting the path to a .csv file containing temperature logger information or a similarly formatted file. Columns should include WATER, YEAR, DAY_N, LOCATION, SITE, METRIC, DEPTH_M, and TEMP_C. 

* **water** -	character vector designating which water to examine. Must be in the same format as the “templogpath” table. Currently this is the legacy all-caps no-abbreviations format (e.g. “LITTLE MOOSE LAKE”)

* **depth** -	depth of readings to consider. Can be numeric (e.g. 2.5) or character (e.g. “AIR” or “BOTTOM”). If an invalid depth is entered the function will return and error and list valid depths for that water.

* **metric** - character value denoting the metric to use for calculations. Common examples include “MEAN”,”MIN” and “MAX”.

* **tempthresh** - numeric value setting the temperature threshold for degree days. Degree days will be counted if the metric value is at or above this value.

* **minday** - minimum ordinal date to include in calculations. Can be used to standardize data ranges among different years or examine a specific period. Ignored if set to NA (default)

* **maxday** - maximum ordinal date to include in calculations. Can be used to standardize data ranges among different years or examine a specific period. Ignored if set to NA (default)
 

###Details
This function calculates the number of degree days and temperature units for a given set of records within the AFRP temperature logger dataset or a similarly formatted file. Water, depth, and metric are required for inputs, as is the temperature threshold to consider.

First the function loads the temperature data using the provided path. This operation utilizes the fread() function from the data.table package as the standard AFRP file is large enough that loading using the base R functions can be quite slow. Then the data is successively filtered to isolate the chosen water, metric, and depth. If minimum and maximum dates are provided further filtering is done to restrict the date range. At each stage a check is made to ensure that some records still remain. If this is not the case, the function will exit with an error message.

Next, the filtered dataset is examined to determine whether the records are continuous throughout the recording interval. If there is a mismatch between the absolute range (i.e. the minimum and maximum ordinal dates for a given year/site/location combination) and the number of records (i.e. the number of unique dates for a combination) a warning is provided and the mismatching entries are listed.

Finally, each temperature record is compared to the provided threshold and set to either 0 (equal to or lesser than) or 1 (greater than). The difference between then threshold and the temperature record is then calculated and multiplied by the above logical vector yielding zeros for values below the threshold and positive differences for those above. These values are summed for each year/site/location combination to produce the degree day metric. Raw temperature values are similarly summed to produce the TU metric. 

### Value
AFRP.degreeday returns a data frame with components YEAR, LOCATION, SITE, WATER, DEPTH_M, METRIC, TEMPTHRESH, DAYSRECORDED, DEGREEDAYS, and TU. The first three columns are used to group records for summation. WATER, DEPTH_M, METRIC, and TEMPTHRESH are set in the original function call and will each contain a single value. DAYSRECORDED reflects the number of unique ordinal dates for a given year/location/site combination. Finally, DEGREEDAYS is the cumulative degrees above the set threshold. TU (temperature units) represents the number of cumulative degrees above zero for each year/location/site combination. 

### Example
```
templogpath = "C:\\Users\\Ben\\Desktop\\Data\\TEMP_ALL_WATERS_5.20.20.csv"

ddresults = AFRP.degreeday(templogpath = templogpath, water='EAST LAKE',
depth = 0.5, metric = 'MEAN', tempthresh =15)
head(ddresults)
```

