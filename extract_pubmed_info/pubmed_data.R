#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(RISmed))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 5) {
    stop("Expected QUERY OUTPUT MIN_YEAR MAX_YEAR RETMAX")
}

search_topic <- args[[1]]
output_path <- args[[2]]
min_year <- as.integer(args[[3]])
max_year <- as.integer(args[[4]])
retmax <- as.integer(args[[5]])
if (any(is.na(c(min_year, max_year, retmax))) || min_year > max_year || retmax < 1) {
    stop("Invalid year range or retmax")
}

search_query <- EUtilsSummary(
    search_topic,
    db = "pubmed",
    retmax = retmax,
    datetype = "pdat",
    mindate = min_year,
    maxdate = max_year
)
records <- EUtilsGet(search_query)
pubmed_data <- data.frame(
    "Title" = ArticleTitle(records),
    "Year" = YearAccepted(records),
    "Cited" = Cited(records),
    "journal" = ISOAbbreviation(records),
    "Abstract" = AbstractText(records),
    "PMID" = PMID(records)
)
write.csv(pubmed_data, file = output_path, row.names = FALSE)
