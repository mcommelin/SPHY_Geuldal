# make all kind of input tables

#initialization
library(tidyverse)

# 1. Soil texture tables --------------------------------------------------------


# load UBC textures
ubc <- read_csv("data/UBC_texture.csv") %>%
  mutate(horizon = str_extract(CODE, "-.*$"),
         layer = if_else(horizon %in% c("-C", "-E"), "sub", "root")) %>%
  group_by(UBC, layer) %>%
  mutate(l_depth = sum(depth, na.rm = T) * 10) %>%
  select(UBC, layer, l_depth, clay, sand, om) %>%
  ungroup()

# save the data for the root layer
ubc_root <- ubc %>%
  filter(layer == "root") %>%
  group_by(UBC) %>%
  select(-layer) %>%
  summarise_all(mean)

depth <- ubc_root %>%
  select(UBC, l_depth) %>%
  rename("rdepth" = "l_depth")

# save data for the sub layer
ubc_sub <- ubc %>%
  filter(layer == "sub") %>%
  group_by(UBC) %>%
  select(-layer) %>%
  summarise_all(mean) %>%
  bind_rows(ubc_root[1, ]) %>%
  left_join(depth, by = "UBC") %>%
  mutate(l_depth = l_depth - rdepth,
         l_depth = if_else(UBC == 100, 200, l_depth))
#write both as tables 
nms <- as.character(seq(0, ncol(ubc_sub) - 1))
names(ubc_sub) <- nms

write.table(ubc_sub, file = "SPHY_data/Geul_200m/maps/soil_sub.tbl",
            sep = " ", row.names = FALSE,
            quote = FALSE)

nms <- as.character(seq(0, ncol(ubc_root) - 1))
names(ubc_root) <- nms

write.table(ubc_root, file = "SPHY_data/Geul_200m/maps/soil_root.tbl",
            sep = " ", row.names = FALSE,
            quote = FALSE)
