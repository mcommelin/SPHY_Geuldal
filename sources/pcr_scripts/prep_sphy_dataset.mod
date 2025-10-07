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
soil = soil.map;

#input tables
soil_s = soil_sub.tbl;
soil_r = soil_root.tbl;

# prepared maps
dem = dem.map;
Ldd = ldd.map;
Slope = slope.map;
stations = stations.map;

# soil maps
rclay = soil_r_clay.map;
rsand = soil_r_sand.map;
rom = soil_r_om.map;
rdepth = soil_r_depth.map;
sclay = soil_s_clay.map;
ssand = soil_s_sand.map;
som = soil_s_om.map;
sdepth = soil_s_depth.map;

# other maps
lat = latitude.map;


initial
# clip to catchment and make ldd and slope
report dem = if(catch, dem_region);
report Ldd = lddcreate(dem, 1e20, 1e20, 1e20, 1e20);
report stations = nominal(pit(Ldd));
report Slope=slope(dem);

# make soil maps
report rclay = lookupscalar(soil_r, 2, soil);
report rsand = lookupscalar(soil_r, 3, soil);
report rom = lookupscalar(soil_r, 4, soil);
report rdepth = lookupscalar(soil_r, 1, soil);
report sclay = lookupscalar(soil_s, 2, soil);
report ssand = lookupscalar(soil_s, 3, soil);
report som = lookupscalar(soil_s, 4, soil);
report sdepth = lookupscalar(soil_s, 1, soil);

report lat = scalar(50);