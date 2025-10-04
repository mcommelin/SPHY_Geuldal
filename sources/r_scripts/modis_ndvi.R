# Script to download 5 min radar precipitation from KNMI and select data the Geul catchment

#load packages
library(tidyverse)
library(lubridate)
library(httr)
library(terra)
library(sf)
library(sp)
library(mapview)
library(rhdf5) #part of Bioconductor install with BiocManager::install("rhdf5")

#turn of stringsAsFactors
options(stringsAsFactors = FALSE)

#seems to be 1 day later stored in file than file name???


# read modis hdf filer, make raster, clip to catchmentsize
files <- dir("data/modis/", pattern = "\\.hdf$", full.names = T)

gdalinfo(files[1])
sds <- sds(files[1])
r <- rast(files[1])

# Save precipitation for Geulcatchment only --------------------------------------
# find pixels in catchment
# the file with radar pixel coordinates was received from Claudia Brauwer - HWM group - WUR
df <- read.table("sources/radarcoordinaten_NL25_1km2_RD.txt", col.names = c("row","col","x","y","V5")) %>%
  select(-V5) %>%
  mutate(latitude = x * 1000,
         longitude = y * 1000)
coordinates(df) <- ~ latitude + longitude
proj4string(df) = CRS("EPSG:28992")
df <- st_as_sf(df)
# load raster of cell ids
ras <- rast("data/processed_data/ID_zones_KNMI_radar.asc")
ras <- ras * 0 + 1
pol <- as.polygons(ras)
crs(pol) <- "epsg:28992"
ca_map <- st_as_sf(pol) %>%
  rename(id = ID_zones_KNMI_radar) 
# check which radar pixels fall in catchment
pixels <- st_join(df, ca_map) %>%
  filter(!is.na(id))
st_write(pixels, "data/processed_data/GIS_data/KNMI_radar_points.gpkg", "pixels", append = F)

# plot the catchment with points the radar pixels that fall inside the catchment
p <- mapView(pixels, color="red")
c <- mapView(ca_map)
p + c

# read HDF5 files list
files <- dir("data/modis/", pattern = "\\.hdf$", full.names = T)
P <- matrix(nrow = length(files), ncol=nrow(pixels))
datetime = vector("character", length = length(files))
for(i in seq_along(files)){
  print(round(i/length(files)*100))
  dat <- h5read(files[i], "image1")
  d <- dat$image_data
  P[i,] <- d[cbind(pixels$col, pixels$row)]
  datetime[i] = str_extract(files[i], "20\\d*")
  h5closeAll()
}
P[P == 65535] = NA
P <- P/100 # change data to mm KNMI data is given in accumulations of 0.01mm

rain <- as_tibble(P, .name_repair = "unique")
names(rain) <- str_extract(names(rain), "\\d.*")
timestmp <- as_tibble_col(datetime, column_name = "timestamp")
rain <- bind_cols(rain, timestmp) %>%
  mutate(timestamp = ymd_hm(timestamp)) %>% 
  mutate(across(-timestamp, ~ .*12))  %>% # change to mm/h

mutate(timestamp = timestamp + hours(1),    # from GMT to GMT + 1
       timestamp = timestamp - minutes(5)) # correct for counting backward of KNMI radar.

write_csv(rain, "data/processed_data/neerslag/KNMI_rain_5min.csv")
