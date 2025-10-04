#! #! --matrixtable --lddin --clone clone.map 
############################################
# Model: SPHY-Geuldal prepare database     #
# Date:  2025-09-24                        #
# Version: 1.0                             #
# Author: Meindert Commelin                #
############################################


binding
# input map layers
dem_region = dem_region.map;
catch = catchment.map;

# prepared maps
dem = dem.map;
Ldd = ldd.map;
Slope = slope.map;
stations = stations.map;


initial

report dem = if(catch, dem_region);
report Ldd = lddcreate(dem, 1e20, 1e20, 1e20, 1e20);
report stations = nominal(pit(Ldd));



