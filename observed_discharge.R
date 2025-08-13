# load discharge and prepare timeseries of daily discharge

library(shiny)
library(leaflet)
library(sf)
library(tidyverse)


# load discharge
head_q <- readLines("data/debietgegevensgeul_LANG.csv", n = 9)
nms <- str_split(head_q[7], ",", simplify = T) %>%
  as.vector(.)
nms[1] <- "timestamp"

# clean up and calculate daily mean discharge (m3/sec)
q_obs <- read_csv("data/debietgegevensgeul_LANG.csv", skip = 9, col_names = FALSE) %>%
  rename_with(~ nms) %>%
  pivot_longer(cols = nms[2:8], names_to = "code", values_to = "Q") %>%
  filter(!is.na(Q)) %>%
  mutate(date = date(timestamp)) %>%
  group_by(code, date) %>%
  summarise(Q = mean(Q))

q_obs_plot <- q_obs %>%
  filter(date > "2010-01-01")

ggplot(q_obs_plot) + 
  geom_line(aes(x = date, y = Q, color = code)) +
  theme_classic()

discharge <- q_obs

# Read locations and convert to sf object
locations <- read.csv("data/discharge_points.csv") # columns: x, y, code
locations_sf <- st_as_sf(locations, coords = c("x", "y"), crs = 28992)
locations_wgs <- st_transform(locations_sf, crs = 4326)
coords <- st_coordinates(locations_wgs)
locations_wgs$lon <- coords[,1]
locations_wgs$lat <- coords[,2]


# Read catchment outline and transform to WGS84
catchment <- st_read("data/GIS_data/geuldal_layers.gpkg", layer = "catch_buffered_250")
catchment_wgs <- st_transform(catchment, crs = 4326)

ui <- fluidPage(
  div(
    leafletOutput("map", height = "60vh"),  # 2/3 of viewport height
    style = "height:60vh;"
  ),
  div(
    uiOutput("dateSlider"),
    plotOutput("dischargePlot", height = "30vh"),  # 1/3 of viewport height
    style = "height:30vh;"
  )
)

server <- function(input, output, session) {
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles("OpenStreetMap.Mapnik") %>%
      addPolygons(data = catchment_wgs, color = "red", weight = 4, fill = FALSE, group = "Catchment") %>%
      addCircleMarkers(
        data = locations_wgs,
        lng = ~lon, lat = ~lat,
        layerId = ~code,
        popup = ~code
      )
  })
  
  selected_code <- reactiveVal(NULL)
  
  observeEvent(input$map_marker_click, {
    selected_code(input$map_marker_click$id)
  })
  
  output$dateSlider <- renderUI({
    req(selected_code())
    df <- filter(discharge, code == selected_code())
    dateRangeInput(
      "dateRange",
      "Select date range:",
      start = min(df$date),
      end = max(df$date),
      min = min(df$date),
      max = max(df$date)
    )
  })
  
  output$dischargePlot <- renderPlot({
    req(selected_code())
    df <- filter(discharge, code == selected_code())
    if (!is.null(input$dateRange)) {
      df <- filter(df, date >= input$dateRange[1], date <= input$dateRange[2])
    }
    ggplot(df, aes(x = date, y = Q)) +
      geom_line(color = "blue") +
      labs(
        title = paste("Discharge at", selected_code()),
        x = "Date",
        y = "Discharge (Q) [m³/s]"
      ) +
      theme_classic()
  })
}

shinyApp(ui, server)
