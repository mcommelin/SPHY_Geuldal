# Initialization --------------------------------------------------------------
library(terra)      
library(sf)         
library(ncdf4)
library(sf)
library(tidyverse)


########################
# extract timeseries
########################

            # Make file name
            data_dir <- "data/"
            files <- dir(data_dir, pattern = ".nc")
            
            filename = paste0(data_dir, files[i])
            
            #check first nc file for dimensions etc
            d_nc = nc_open(filename)
            
            nc_close(d_nc)
            
            # Extract the data to a 3-dimensional matrix:
            # Dimension 1: 705 points for longitude: -25 degrees E
            # Dimension 2: 465 points for latitude: 25 - degrees N
            # Dimension 4: 5114 time steps: 15 years of daily values
           
         # # filter catchment size data
            
            # Make vectors for all ranges
            lons = round(seq(-25, 45.5, length.out=705),2)
            lats = seq(25, 71.4, by=0.1)
            
            days_dates <- seq(ymd("20110101"), ymd("20241231"), by = "day")
            times <- seq(22280, 22280 + 5113, by =1)

            # Compute length
            nLon = length(lons)
            nLat = length(lats)
            nTimes = length(times)
            
            
            ########################
            # Coordinates all pixels
            ########################
            
            # Make spatial object for pixels
            pix_all_sp = vect(cbind(longitude = rep(lons,nLat), 
                                    latitude = rep(lats, each=length(lons))), 
                              atts = data.frame(idx_lon = rep((1:nLon), nLat), 
                                                idx_lat = rep((1:nLat), each=nLon)), 
                              crs="EPSG:4326")

            # Add border Geuldal to the map
            
            # Load border NL
            Geuld_RD = st_read("data/GIS_data/geuldal_layers.gpkg", layer = "region_outline")  
            
            # Reproject
            Geul_latlon = st_transform(Geuld_RD, crs = "EPSG:4326")
            cat_latlon <- vect(Geul_latlon)

            ############################
            # Select pixels in catchment
            ############################
            
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
              
            #load the different weather .nc file. They are very large and need up to
            # 32GB ram in the process of reading, so make sure no unneeded processes
            # are running.
            name_part <- str_extract(files, "^..")
            
            for (i in seq_along(files)) {
            
            filename = paste0(data_dir, files[i])
            d_nc = nc_open(filename)
            d_all = ncvar_get(d_nc)
            nc_close(d_nc)
            
            
            #####################
            # Extract time series
            #####################
            
            
            
            # Make matrix for P or ET of all days (rows) and all pixels (cols)
            d_cat = matrix(nrow = nTimes, ncol = nPix)
            
            # Loop over all pixels
            for (iPix in 1:nPix) { 
                
              d_cat[, iPix] = 
                d_all[pix_cat_df$idx_lon[iPix], pix_cat_df$idx_lat[iPix], ]
            }
            
            # remove d_all to create space
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