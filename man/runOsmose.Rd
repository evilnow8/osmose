% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/osmose-main.R
\name{runOsmose}
\alias{runOsmose}
\title{Run an OSMOSE configuration}
\usage{
runOsmose(osmose = NULL, java = "java", input = "input/config.csv",
  output = "output/", options = NULL, log = "osmose.log",
  verbose = NULL, clean = TRUE)
}
\arguments{
\item{file}{Filename of the main configuration file
a new file is created with the modified configuration.}
}
\description{
This function create a valid configuration by several input files
from user input parameters.
}
\details{
Basic configurations may not need the use of \code{buildConfiguration},
but it is required for configuration using interannual inputs or fishing selectivity.
}
\author{
Ricardo Oliveros-Ramos
}

