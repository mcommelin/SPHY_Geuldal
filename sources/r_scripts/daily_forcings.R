# download daily weather data for 2011-2023

# 1. MODIS 16 day timeseries NDVI 1km2
# https://data.europa.eu/data/datasets/4ea3b1e9-d3d0-4c3f-afb1-6445cec3a89d?locale=en

# 2. europe data https://surfobs.climate.copernicus.eu/dataaccess/access_eobs_chunks.php

# Initialization ---------------------------------------------------------------
#load packages
library(tidyverse)
library(terra)
library(sf)
library(ncdf4)


#turn of stringsAsFactors
options(stringsAsFactors = FALSE)

# load pcraster functions
source("sources/r_scripts/pcrasteR.R")
set_pcraster(env = "sphy", miniconda = "~/ProgramFiles/miniconda3")

# we manually downloaded the data from MODIS for NDVI and from E-OBS for weather

## 1.1 date settings SPHY dataset ---------------------------------------------
# make a sequence with dates and day number for forcing output
start_date <- ymd("20110101")
end_date <- ymd("20231231")

daynums <- tibble(date = seq(start_date, end_date, by = "day"),
                  days = seq(1, 4748, by = 1)) %>%
  mutate(day_string = as.character(days),
         day_string = str_pad(day_string, 7, "left", "0"),
         day_start = str_extract(day_string, "^\\d{4}"),
         day_string = str_replace(day_string, "^\\d{4}", paste0(day_start, "."))) %>%
  select(-day_start)

# 2. make ndvi maps -----------------------------------------------------------
# read modis hdf file, make raster, clip to catchmentsize
files <- dir("/home/mc/Werk/Data/Geuldal_GIS/SPHY/modis", pattern = "\\.hdf$", full.names = T)

# load 200m mask, as spatraster
mask <- rast("SPHY_data/Geul_200m/maps/clone.map")
crs(mask) <- "EPSG:28992"

for (i in seq_along(files)) {
  file <- files[i]
  yearday <- str_extract(file, "20\\d{5}")
  year <- str_extract(yearday, "^\\d{4}")
  day <- str_extract(yearday, "\\d{3}$")
  fdate <- strptime(yearday, format = "%Y%j")
  
  end <- filter(daynums, date == fdate)$day_string
  
  # if the date is not within range defined at top, go to next file.
  if (length(end) == 0) next
  
  out <- paste0("SPHY_data/Geul_200m/ndvi_2011_2024/ndvi", end)
  
  # read the raster file, 12 bands, select the ndvi = band 1
  mod_ras <- rast(file)
  ndvi_ras <- mod_ras[[1]]
  
  # metadata scaling factor seems wrong
  ndvi_ras <- ndvi_ras * 0.0001 * 0.0001
  
  # transform to EPSG:28992 and clip to mask
  ndvi_geul <- terra::project(ndvi_ras, mask, method = "near")
  # save as tif file
  writeRaster(ndvi_geul, "ndvi.asc", filetype = "AAIgrid", NAflag = -9999,
              overwrite = TRUE)
  # asc2map
  asc2map(clone = "SPHY_data/Geul_200m/maps/clone.map",
          map_in = "ndvi.asc",
          map_out = out,
          options = "-S")
}

# 3. extract weather data ---------------------------------------------------

# load data files
data_dir <- "data/"
files <- dir(data_dir, pattern = ".nc")

## 3.1 setup -------------------------------------------------------------------
filename = paste0(data_dir, files[1])

#check first nc file for dimensions etc
d_nc = nc_open(filename)

nc_close(d_nc)

# Extract the data to a 3-dimensional matrix:
# Dimension 1: 705 points for longitude: -25 degrees E
# Dimension 2: 465 points for latitude: 25 - degrees N
# Dimension 4: 5114 time steps: 15 years of daily values

# Make vectors for all ranges
lons = round(seq(-25, 45.5, length.out=705),2)
lats = seq(25, 71.4, by=0.1)

days_dates <- seq(ymd("20110101"), ymd("20241231"), by = "day")
times <- seq(22280, 22280 + 5113, by =1)

# Compute length
nLon = length(lons)
nLat = length(lats)
nTimes = length(times)

# Make spatial object for pixels
pix_all_sp = vect(cbind(longitude = rep(lons,nLat), 
                        latitude = rep(lats, each=length(lons))), 
                  atts = data.frame(idx_lon = rep((1:nLon), nLat), 
                                    idx_lat = rep((1:nLat), each=nLon)), 
                  crs="EPSG:4326")

# Load border catchment
Geuld_RD = st_read("data/GIS_data/geuldal_layers.gpkg", layer = "region_outline")  

# Reproject
Geul_latlon = st_transform(Geuld_RD, crs = "EPSG:4326")
cat_latlon <- vect(Geul_latlon)

# Cut out the pixels within the catchment
pix_cat_sp = terra::intersect(pix_all_sp, cat_latlon)

# Check
# pix_cat_sp
# points(pix_cat_sp, col = "red", pch="+", cex=0.7)

# Make dataframe with the ID (index number), lat and lon
pix_cat_df     = data.frame(idx_lon = pix_cat_sp$idx_lon, idx_lat = pix_cat_sp$idx_lat)
pix_cat_df$lon = crds(pix_cat_sp)[,1]
pix_cat_df$lat = crds(pix_cat_sp)[,2]

# Count number of pixels in catchment
nPix = nrow(pix_cat_df)

# Write coordinates and figure to file (only necessary once)
# Write to file
#  write.table(pix_cat_df, paste0("data/pixels_", cat_ID, ".dat"), row.names=F)

## 3.2 Extract data nc file ----------------------------------------------------
#load the different weather .nc file. They are very large and need up to
# 32GB ram in the process of reading, so make sure no unneeded processes
# are running.
name_part <- str_extract(files, "^..")

for (i in seq_along(files)) {
  # extract the data from the nc file
  filename = paste0(data_dir, files[i])
  d_nc = nc_open(filename)
  d_all = ncvar_get(d_nc)
  nc_close(d_nc)
  
  # Make matrix for all days (rows) and all pixels (cols)
  d_cat = matrix(nrow = nTimes, ncol = nPix)
  
  # Loop over all pixels and fill with data
  for (iPix in 1:nPix) { 
        d_cat[, iPix] = 
      d_all[pix_cat_df$idx_lon[iPix], pix_cat_df$idx_lat[iPix], ]
  }
  
  # remove d_all to create RAM space
  rm(d_all)
  
  # save the table as csv
  dat <- as_tibble(d_cat) %>%
    rename_with(~ as.character(1:nPix)) %>%
    mutate(time = times,
           date = days_dates)
  
  write_csv(dat, paste0("data/E_OBS_", name_part[i], ".csv"))
  
  #free ram memory before next nc file
  gc()
}

# 4. make weather maps ---------------------------------------------------------


# load the pixels coordinates
pix <- read_delim("data/pixels_Geul.dat") %>%
  select(-idx_lat, - idx_lon)

# load 200m mask, as spatraster
mask <- rast("SPHY_data/Geul_200m/maps/clone.map")
crs(mask) <- "EPSG:28992"

# add loop over different weather params
files <- dir("data/", pattern = "^E_OBS")
wtype <- c("prec", "tavg", "tmin", "tmax")
for (j in 1:3) {
#load the data and select dates within range
dat <- read_csv(paste0("data/", files[j])) %>%
  filter(date >= start_date & date <= end_date)

dat_t <- t(dat[-(30:31)])
n <- ncol(dat_t)
for (i in 1:n) {
  fdate <- dat$date[i] 
  end <- filter(daynums, date == fdate)$day_string
  out <- paste0("SPHY_data/Geul_200m/forcings/", wtype[j], end)
  map <- pix %>%
    mutate(d = dat_t[, i])
  
  ras <- rast(map, type = "xyz")
  crs(ras) <- "EPSG:4326"
  
  # reproject id raster
  ras1 <- terra::project(ras, mask)
  #plot(ras1)
  
  # save to timeseries
  writeRaster(ras1, "ras.asc", filetype = "AAIgrid", NAflag = -9999,
              overwrite = TRUE)
  # asc2map
  asc2map(clone = "SPHY_data/Geul_200m/maps/clone.map",
          map_in = "ras.asc",
          map_out = out,
          options = "-S")
  
  
} # end timeseries loop

} # end files loop

