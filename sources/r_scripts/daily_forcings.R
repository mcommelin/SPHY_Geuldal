# download daily weather data for 2010-2024

# available datasets:
# 1. gridded daily precipitation:
# https://dataplatform.knmi.nl/dataset/rd1-5

#api endpoint:
#https://api.dataplatform.knmi.nl/open-data/v1/datasets/Rd1/versions/5/files

# 2. mean temperature:
# https://dataplatform.knmi.nl/dataset/tg1-5

# 3. daily minimun temp:
# https://dataplatform.knmi.nl/dataset/tn1-2

# 4. daily max temp:
# https://dataplatform.knmi.nl/dataset/tx1-2

# 5. MODIS 16 day timeseries NDVI 1km2
# https://data.europa.eu/data/datasets/4ea3b1e9-d3d0-4c3f-afb1-6445cec3a89d?locale=en

# 6. europe data https://surfobs.climate.copernicus.eu/dataaccess/access_eobs_chunks.php

# Initialization ---------------------------------------------------------------
#load packages
library(tidyverse)
library(lubridate)
library(httr)
library(terra)
library(sf)
library(sp)
library(mapview)
library(rhdf5) #part of Bioconductor install with BiocManager::install("rhdf5")

# use meteoland package?

#turn of stringsAsFactors
options(stringsAsFactors = FALSE)

# Download data from KNMI API --------------------------------------------------

#use anonymous key from: https://developer.dataplatform.knmi.nl/get-started
key <- "eyJvcmciOiI1ZTU1NGUxOTI3NGE5NjAwMDEyYTNlYjEiLCJpZCI6ImVlNDFjMWI0MjlkODQ2MThiNWI4ZDViZDAyMTM2YTM3IiwiaCI6Im11cm11cjEyOCJ9"
# or register and use registered key - better performance
key <- "eyJvcmciOiI1ZTU1NGUxOTI3NGE5NjAwMDEyYTNlYjEiLCJpZCI6IjNhNjJiZWViZTBkMDRmNWM5MWIyNWJlMGY0NGY4MjdkIiwiaCI6Im11cm11cjEyOCJ9"

start_date <- ymd("20100101")
end_date <- ymd("20141231")

dates <- seq(start_date, end_date, by = "days")

#adjust file name and api endpoint for different sources.

# download data for all selected days
for (i in 1242:1826) { #seq_along(dates)) {
  date1 <- str_remove_all(as.character(ymd(dates[i])), "-")
  date2 <- str_remove_all(as.character(ymd(dates[i]) + 1), "-")
  file <- str_c("INTER_OPER_R___TX1_____L3__", date1, "T000000_", date2, "T000000_0002.nc")
  file_save <- str_c("data/KNMI/tmax/", file)
  url <- str_c("https://api.dataplatform.knmi.nl/open-data/v1/datasets/Tx1/versions/2/files/", file, "/url")
  r <- GET(url = url, add_headers(Authorization = key))
  con <- content(r, "parsed")
  url_2 <- con$temporaryDownloadUrl
  GET(url =  url_2, write_disk(file_save, overwrite = T))
}
