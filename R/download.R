# Copyright 2017 Province of British Columbia
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.


#' Download a tibble of realtime discharge data from the Meteorological Service of Canada datamart
#'
#' Download realtime discharge data from the Meteorological Service of Canada (MSC) datamart. The function will prioritize
#' downloading data collected at the highest resolution. In instances where data is not available at high (hourly or higher) resolution
#' daily averages are used. Currently, if a station does not exist or is not found, no data is returned.
#'
#' @param station_number Water Survey of Canada station number. If this argument is omitted from the function call, the value of \code{prov_terr_state_loc}
#' is returned.
#' @param prov_terr_state_loc Province, state or territory. If this argument is omitted from the function call, the value of \code{station_number}
#' is returned.
#'
#' @return A tibble of water flow and level values. 
#' 
#' @format A tibble with 8 variables:
#' \describe{
#'   \item{STATION_NUMBER}{Unique 7 digit Water Survey of Canada station number}
#'   \item{PROV_TERR_STATE_LOC}{The province, territory or state in which the station is located}
#'   \item{Date}{Observation date and time. Formatted as a POSIXct class as UTC for consistency.}
#'   \item{Parameter}{Parameter being measured. Only possible values are FLOW and LEVEL}
#'   \item{Value}{Value of the measurement. If Parameter equals FLOW the units are m^3/s. If Parameter equals LEVEL the 
#'   units are metres.}
#'   \item{Grade}{future use}
#'   \item{Symbol}{future use}
#'   \item{Code}{quality assurance/quality control flag for the discharge}
#' }
#'
#' @examples
#' ## Download from multiple provinces
#' realtime_dd(station_number=c("01CD005","08MF005"))
#'
#' # To download all stations in Prince Edward Island:
#' realtime_dd(prov_terr_state_loc = "PE")
#' 
#' @family realtime functions
#' @export
realtime_dd <- function(station_number = NULL, prov_terr_state_loc) {

  ## TODO: HAve a warning message if not internet connection exists
  if (!is.null(station_number) && station_number == "ALL") {
    stop("Deprecated behaviour.Omit the station_number = \"ALL\" argument. See ?realtime_dd for examples.")
  }


  if (!is.null(station_number)) {
    stns <- station_number
    choose_df <- realtime_stations()
    choose_df <- dplyr::filter(choose_df, STATION_NUMBER %in% stns)
    choose_df <- dplyr::select(choose_df, STATION_NUMBER, PROV_TERR_STATE_LOC)
  }

  if (is.null(station_number)) {
    choose_df <- realtime_stations(prov_terr_state_loc = prov_terr_state_loc)
    choose_df <- dplyr::select(choose_df, STATION_NUMBER, PROV_TERR_STATE_LOC)
  }

  output_c <- c()
  for (i in seq_along(choose_df$STATION_NUMBER)) {
    ## Specify from choose_df
    STATION_NUMBER_SEL <- choose_df$STATION_NUMBER[i]
    PROV_SEL <- choose_df$PROV_TERR_STATE_LOC[i]


    base_url <- "http://dd.weather.gc.ca/hydrometric"

    # build URL
    type <- c("hourly", "daily")
    url <-
      sprintf("%s/csv/%s/%s", base_url, PROV_SEL, type)
    infile <-
      sprintf(
        "%s/%s_%s_%s_hydrometric.csv",
        url,
        PROV_SEL,
        STATION_NUMBER_SEL,
        type
      )

    # Define column names as the same as HYDAT
    colHeaders <-
      c(
        "STATION_NUMBER",
        "Date",
        "LEVEL",
        "LEVEL_GRADE",
        "LEVEL_SYMBOL",
        "LEVEL_CODE",
        "FLOW",
        "FLOW_GRADE",
        "FLOW_SYMBOL",
        "FLOW_CODE"
      )
    
    url_check <- httr::GET(infile[1])
    ## check if a valid url
    if(httr::http_error(url_check) == TRUE){
      message(paste0("No hourly data found for ",STATION_NUMBER_SEL))
      
      h <- tibble::tibble(A = STATION_NUMBER_SEL, B = NA, C = NA, D = NA, E = NA,
                     F = NA, G = NA, H = NA, I = NA, J = NA)
      
      colnames(h) <- colHeaders
    } else{
      h <- httr::content(
        url_check,
        type = "text/csv",
        encoding = "UTF-8",
        skip = 1,
        col_names = colHeaders,
        col_types = readr::cols(
          STATION_NUMBER = readr::col_character(),
          Date = readr::col_datetime(),
          LEVEL = readr::col_double(),
          LEVEL_GRADE = readr::col_character(),
          LEVEL_SYMBOL = readr::col_character(),
          LEVEL_CODE = readr::col_integer(),
          FLOW = readr::col_double(),
          FLOW_GRADE = readr::col_character(),
          FLOW_SYMBOL = readr::col_character(),
          FLOW_CODE = readr::col_integer()
        )
      )
    }

    # download daily file
    url_check_d <- httr::GET(infile[2])
    ## check if a valid url
    if(httr::http_error(url_check_d) == TRUE){
      message(paste0("No daily data found for ",STATION_NUMBER_SEL))
      
      d <- tibble::tibble(A = NA, B = NA, C = NA, D = NA, E = NA,
                          F = NA, G = NA, H = NA, I = NA, J = NA)
      colnames(d) <- colHeaders
    } else{
      d <- httr::content(
        url_check_d,
        type = "text/csv",
        encoding = "UTF-8",
        skip = 1,
        col_names = colHeaders,
        col_types = readr::cols(
          STATION_NUMBER = readr::col_character(),
          Date = readr::col_datetime(),
          LEVEL = readr::col_double(),
          LEVEL_GRADE = readr::col_character(),
          LEVEL_SYMBOL = readr::col_character(),
          LEVEL_CODE = readr::col_integer(),
          FLOW = readr::col_double(),
          FLOW_GRADE = readr::col_character(),
          FLOW_SYMBOL = readr::col_character(),
          FLOW_CODE = readr::col_integer()
        )
      )
    }
    


    # now merge the hourly + daily (hourly data overwrites daily where dates are the same)
    if(NROW(stats::na.omit(h)) == 0){
      output <- d
    } else{
      p <- which(d$Date < min(h$Date))
      output <- rbind(d[p, ], h)
    }

    ## Now tidy the data
    ## TODO: Find a better way to do this
    output <- dplyr::rename(output, `LEVEL_` = LEVEL, `FLOW_` = FLOW)
    output <- tidyr::gather(output, temp, val, -STATION_NUMBER, -Date)
    output <- tidyr::separate(output, temp, c("Parameter", "key"), sep = "_", remove = TRUE)
    output <- dplyr::mutate(output, key = ifelse(key == "", "Value", key))
    output <- tidyr::spread(output, key, val)
    output <- dplyr::rename(output, Code = CODE, Grade = GRADE, Symbol = SYMBOL)
    output <- dplyr::mutate(output, PROV_TERR_STATE_LOC = PROV_SEL)
    output <- dplyr::select(output, STATION_NUMBER, PROV_TERR_STATE_LOC, Date, Parameter, Value, Grade, Symbol, Code)
    output <- dplyr::arrange(output, Parameter, STATION_NUMBER, Date)
    output$Value <- as.numeric(output$Value)



    output_c <- dplyr::bind_rows(output, output_c)
  }
  output_c
}


#' Download a tibble of active realtime stations
#'
#' An up to date dataframe of all stations in the Realtime Water Survey of Canada 
#'   hydrometric network operated by Environment and Climate Change Canada
#'
#' @param prov_terr_state_loc Province/State/Territory or Location. See examples for list of available options. 
#'   realtime_stations() for all stations.
#'
#' @family realtime functions
#' 
#' @format A tibble with 6 variables:
#' \describe{
#'   \item{STATION_NUMBER}{Unique 7 digit Water Survey of Canada station number}
#'   \item{STATION_NAME}{Official name for station identification}
#'   \item{LATITUDE}{North-South Coordinates of the gauging station in decimal degrees}
#'   \item{LONGITUDE}{East-West Coordinates of the gauging station in decimal degrees}
#'   \item{PROV_TERR_STATE_LOC}{The province, territory or state in which the station is located}
#'   \item{TIMEZONE}{Timezone of the station}
#' }
#' 
#' @export
#'
#' @examples
#' \dontrun{
#' ## Available inputs for prov_terr_state_loc argument:
#' unique(realtime_stations()$prov_terr_state_loc)
#'
#' realtime_stations(prov_terr_state_loc = "BC")
#' realtime_stations(prov_terr_state_loc = c("QC","PE"))
#' }


realtime_stations <- function(prov_terr_state_loc = NULL) {
  prov <- prov_terr_state_loc

  url_check <- httr::GET("http://dd.weather.gc.ca/hydrometric/doc/hydrometric_StationList.csv")
  
  ## Checking to make sure the link is valid
  if(httr::http_error(url_check) == "TRUE"){
    stop("http://dd.weather.gc.ca/hydrometric/doc/hydrometric_StationList.csv is not a valid url. Datamart may be
         down or the url has changed.")
  }
  
  net_tibble <- httr::content(url_check,
                              type = "text/csv",
                              encoding = "UTF-8",
                              skip = 1,
                              col_names = c(
                                "STATION_NUMBER",
                                "STATION_NAME",
                                "LATITUDE",
                                "LONGITUDE",
                                "PROV_TERR_STATE_LOC",
                                "TIMEZONE"
                              ),
                              col_types = readr::cols()
                          )
  
  if (is.null(prov)) {
    return(net_tibble)
  }

  net_tibble <- dplyr::filter(net_tibble, PROV_TERR_STATE_LOC %in% prov)
  net_tibble
}

#' Request a token from the Environment and Climate Change Canada [EXPERIMENTAL]
#' @param username Supplied by ECCC. Defaults to NULL which will use WS_USRNM from .Renviron file
#' @param password Supplied by ECCC. Defaults to NULL which will use WS_PWD from .Renviron file
#' Request a token from the ECCC web service using the POST method. This token expires after 10 minutes.
#' You can only have 5 tokens out at once.
#'
#' @details The \code{username} and \code{password} should be treated carefully and should never be entered directly into an r script or console.
#' Rather these credentials should be stored in your \code{.Renviron} file. The .Renviron file can edited using \code{file.edit("~/.Renviron")}.
#' In that file, which is only stored locally and is only available to you, you can assign your \code{username} to WS_USRNM and \code{password} 
#' to WS_PWD and then simply issue \code{token_ws}. See \code{?download_ws} for examples.
#'
#' @return The token as a string that should be supplied the \code{download_ws_realtime} function. 
#' 
#' 
#' @family realtime functions
#' @export
#'


token_ws <- function(username = NULL, password = NULL) {
  
  if(is.null(username) | is.null(password)){
    username <- Sys.getenv("WS_USRNM")
    password <- Sys.getenv("WS_PWD")
  }
  
  login <- list(
    username = username,
    password = password
  )
  r <- httr::POST("https://wateroffice.ec.gc.ca/services/auth", body = login)
  
  ## A workaround that pauses for the connection 
  Sys.sleep(2)

  ## If the POST request was not a successful, print out why.
  ## Possibly could provide errors as per web service guidelines
  if (httr::status_code(r) == 422) {
    stop("422 Unprocessable Entity: Username and/or password are missing or are formatted incorrectly.")
  }

  if (httr::status_code(r) == 403) {
    stop("403 Forbidden: the web service is denying your request. Try any of the following options: 
          -Ensure you are not currently using all 5 tokens
          -Wait a few minutes and try again 
          -Copy the token_ws call and paste it directly into the console
          -Try using realtime_ws if you only need water quantity data
         ")
  }

  ## Catch all error for anything not covered above.
  httr::stop_for_status(r)

  message(paste0("This token will expire at ", format(Sys.time() + 10 * 60, "%H:%M:%S")))

  ## Extract token from POST
  token <- httr::content(r, "text", encoding = "UTF-8")

  token
}

#' Download realtime data from the ECCC web service [EXPERIMENTAL]
#' 
#' Function to actually retrieve data from ECCC web service. Before using this function,
#' a token from \code{token_ws()} is needed. The maximum number of days that can be 
#' queried depends on other parameters being requested. If one station is requested, 18 
#' months of data can be requested. If you continually receiving errors when invoking this
#' function, reduce the number of observations (via station_number, parameters or dates) being requested. 
#' 
#' @param station_number Water Survey of Canada station number.
#' @param parameters parameter ID. Can take multiple entries. Parameter is a numeric code. See \code{param_id} for options. Defaults to all parameters.
#' @param start_date Need to be in YYYY-MM-DD. Defaults to 30 days before current date. 
#' @param end_date Need to be in YYYY-MM-DD. Defaults to current date.
#' @param token generate by \code{token_ws()}
#' 
#' 
#' @format A tibble with 6 variables:
#' \describe{
#'   \item{STATION_NUMBER}{Unique 7 digit Water Survey of Canada station number}
#'   \item{Date}{Observation date and time. Formatted as a POSIXct class as UTC for consistency.}
#'   \item{Name_En}{Code name in English}
#'   \item{Value}{Value of the measurement.}
#'   \item{Unit}{Value units}
#'   \item{Grade}{future use}
#'   \item{Symbol}{future use}
#'   \item{Approval}{future use}
#'   \item{Parameter}{Numeric parameter code}
#'   \item{Code}{Letter parameter code}
#' }
#'
#' @examples
#' \dontrun{
#' token_out <- token_ws()
#'
#' ws_08 <- realtime_ws(station_number = c("08NL071","08NM174"),
#'                          parameters = c(47, 5),
#'                          token = token_out)
#'
#' fivedays <- realtime_ws(station_number = c("08NL071","08NM174"),
#'                          parameters = c(47, 5),
#'                          end_date = Sys.Date(), #today
#'                          start_date = Sys.Date() - 5, #five days ago
#'                          token = token_out)
#' }
#' @family realtime functions
#' @export


realtime_ws <- function(station_number, parameters = c(46, 16, 52, 47, 8, 5, 41, 18),
                                 start_date = Sys.Date() - 30, end_date = Sys.Date(), token) {
  if (length(station_number) >= 300) {
    stop("Only 300 stations are supported for one request. If more stations are required, 
         a separate request should be issued to include the excess stations. This second request will 
         require an additional token.")
  }
  
  
  ## Check date is in the right format
  if (is.na(as.Date(start_date, format = "%Y-%m-%d")) | is.na(as.Date(end_date, format = "%Y-%m-%d"))) {
    stop("Invalid date format. Dates need to be in YYYY-MM-DD format")
  }

  #if (as.Date(end_date) - as.Date(start_date) > 60) {
  #  stop("The time period of data being requested should not exceed 2 months. 
  #       If more data is required, then a separate request should be issued to include a different time period.")
  #}
  ## English parameter names

  ## Is it a valid parameter name?

  ## Is it a valid Station name?


  ## Build link for GET
  baseurl <- "https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline?"
  station_string <- paste0("stations[]=", station_number, collapse = "&")
  parameters_string <- paste0("parameters[]=", parameters, collapse = "&")
  date_string <- paste0("start_date=", start_date, "%2000:00:00&end_date=", end_date, "%2023:59:59")
  token_string <- paste0("token=", token)

  ## paste them all together
  url_for_GET <- paste0(
    baseurl,
    station_string, "&",
    parameters_string, "&",
    date_string, "&",
    token_string
  )

  ## Get data
  get_ws <- httr::GET(url_for_GET)
  
  ## Give webservice some time
  Sys.sleep(1)

  if (httr::status_code(get_ws) == 403) {
    stop("403 Forbidden: the web service is denying your request. Try any of the following options: 
          -Ensure you are not currently using all 5 tokens
         -Wait a few minutes and try again 
         -Copy the token_ws call and paste it directly into the console
         -Try using realtime_ws if you only need water quantity data
         ")
  }

  ## Check the GET status
  httr::stop_for_status(get_ws)

  if (httr::headers(get_ws)$`content-type` != "text/csv; charset=utf-8") {
    stop("GET response is not a csv file")
  }

  ## Turn it into a tibble and specify correct column classes
  csv_df <- httr::content(
    get_ws,
    type = "text/csv",
    encoding = "UTF-8",
    col_types = readr::cols(
      ID = readr::col_character(),
      Date = readr::col_datetime(),
      Parameter = readr::col_integer(),
      Value = readr::col_double(),
      Grade = readr::col_character(),
      Symbol = readr::col_character(),
      Approval = readr::col_integer()
    )
  )
  


  ## Check here to see if csv_df has any data in it
  if (nrow(csv_df) == 0) {
    stop("No data exists for this station query")
  }

  ## Rename columns to reflect tidyhydat naming
  csv_df <- dplyr::rename(csv_df, STATION_NUMBER = ID)
  csv_df <- dplyr::left_join(
    csv_df,
    dplyr::select(param_id, -Name_Fr),
    by = c("Parameter")
  )
  csv_df <- dplyr::select(csv_df, STATION_NUMBER, Date, Name_En, Value, Unit, Grade, Symbol, Approval, Parameter, Code)

  ## What stations were missed?
  differ <- setdiff(unique(station_number), unique(csv_df$STATION_NUMBER))
  if (length(differ) != 0) {
    if (length(differ) <= 10) {
      message("The following station(s) were not retrieved: ", paste0(differ, sep = " "))
      message("Check station number for typos or if it is a valid station in the network")
    }
    else {
      message("More than 10 stations from the initial query were not returned. Ensure realtime and active status are correctly specified.")
    }
  } else {
    message("All station successfully retrieved")
  }

  ## Return it
  csv_df

  ## Need to output a warning to see if any stations weren't retrieved
}

#' Download and set the path to HYDAT
#'
#' Download the HYDAT sqlite database. This database contains all the historical hydrometric data for Canada's integrated hydrometric network.
#' The function will check for a existing sqlite file and won't download the file if the same version is already present. 

#'
#' @param dl_hydat_here Directory to the HYDAT database. The path is chosen by the \code{rappdirs} package and is OS specific and can be view by \code{hy_dir}. 
#' This path is also supplied automatically to any function that uses the HYDAT database. A user specified path can be set though this is not the advised approach. 
#' It also downloads the database to a directory specified by \code{hy_dir}.
#' @export
#'
#' @examples \dontrun{
#' download_hydat()
#' }
#'

download_hydat <- function(dl_hydat_here = NULL) {
  
  if(is.null(dl_hydat_here)){
    dl_hydat_here <- hy_dir()
  }
  
  response <- readline(prompt = "Downloading HYDAT will take approximately 10 minutes. Are you sure you want to continue? (Y/N) ")

  if (!response %in% c("Y", "Yes", "yes", "y")) {
    stop("Maybe another day...")
  }
  
  message(paste0("Downloading HYDAT.sqlite3 to ",dl_hydat_here))


  ## Create actual hydat_path
  hydat_path <- paste0(dl_hydat_here, "\\Hydat.sqlite3")

  temp <- tempfile()


  ## If there is an existing hydat file get the date of release
  if (length(list.files(dl_hydat_here, pattern = "Hydat.sqlite3")) == 1) {
    hy_version(hydat_path) %>%
      dplyr::mutate(condensed_date = paste0(
        substr(Date, 1, 4),
        substr(Date, 6, 7),
        substr(Date, 9, 10)
      )) %>%
      dplyr::pull(condensed_date) -> existing_hydat
  } else {
    existing_hydat <- "HYDAT not present"
  }


  ## Create the link to download HYDAT
  base_url <- "http://collaboration.cmc.ec.gc.ca/cmc/hydrometrics/www/"
  x <- httr::GET(base_url)
  httr::stop_for_status(x)
  new_hydat <- substr(gsub(
    "^.*\\Hydat_sqlite3_", "",
    httr::content(x, "text")
  ), 1, 8)

  ## Do we need to download a new version?
  if (new_hydat == existing_hydat) {
    stop(paste0("The existing local version of hydat, published on ", lubridate::ymd(existing_hydat), ", is the most recent version available."))
  } else {
    message(paste0("Downloading version of hydat published on ", lubridate::ymd(new_hydat)))
  }

  url <- paste0(base_url, "Hydat_sqlite3_", new_hydat, ".zip")

  utils::download.file(url, temp)

  utils::unzip(temp, files = (utils::unzip(temp, list = TRUE)$Name[1]), exdir = dl_hydat_here, overwrite = TRUE)
  
  invisible(TRUE)
}
