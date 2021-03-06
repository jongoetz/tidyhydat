% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hy_stn_.R
\name{hy_stn_remarks}
\alias{hy_stn_remarks}
\title{Extract station remarks from HYDAT database}
\format{A tibble with 4 variables:
\describe{
  \item{STATION_NUMBER}{Unique 7 digit Water Survey of Canada station number}
  \item{REMARK_TYPE_EN}{Type of Remark}
  \item{YEAR}{Year of the remark}
  \item{REMARK_EN}{Remark}
}}
\usage{
hy_stn_remarks(station_number = NULL, hydat_path = NULL,
  prov_terr_state_loc = NULL)
}
\arguments{
\item{station_number}{A seven digit Water Survey of Canada station number. If this argument is omitted, the value of \code{prov_terr_state_loc}
is returned.}

\item{hydat_path}{The default for this argument is to look for hydat in the same location where it
was saved by using \code{download_hydat}. Therefore this argument is almost always omitted from a function call. 
You can see where hydat was downloaded using \code{hy_dir()}}

\item{prov_terr_state_loc}{Province, state or territory. If this argument is omitted, the value of \code{station_number}
is returned. See \code{unique(allstations$prov_terr_state_loc)}}
}
\value{
A tibble of hy_stn_remarks
}
\description{
hy_stn_remarks look-up Table
}
\examples{
\dontrun{
hy_stn_remarks(station_number = c("02JE013","08MF005"))
}

}
