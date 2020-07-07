#!/usr/bin/env Rscript
library(RISmed)
args<-commandArgs(T)
search_topic <- c(args[1])
search_query <- EUtilsSummary(search_topic, db="pubmed", retmax=100, datetype='pdat', mindate=2010, maxdate=2020)
records<- EUtilsGet(search_query)
pubmed_data <- data.frame('Title'=ArticleTitle(records),
                          'Year'=YearAccepted(records),
                          'Cited'=Cited(records),
                          'journal'=ISOAbbreviation(records),
                          'Abstract'=AbstractText(records),
                          'PMID'=PMID(records))
write.csv(pubmed_data,file=args[2],row.names = FALSE)