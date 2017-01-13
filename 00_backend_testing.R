#Federal Register API examples
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 12/7/16

#setup

if (!require("curl")) install.packages("curl")
if (!require("devtools")) install.packages("devtools")

library(curl)
library(devtools)
install_github('rOpenGov/federalregister')
library(federalregister)


#topic search
x <- fr_search(term='fisheries', per_page=100, order='newest')
cat(x$results$title[1:10], sep='\n\n') #first ten titles by most recent
cat(x$results$publication_date[1:10]) #dates
cat(x$results$abstract[1]) #first abstract

#title search?

#not sure how to target specific document sections for keyword search. the 'term' argument seems to
#include both title and excerpt fields (maybe abstract too)

#agency search
x <- fr_search(term='arctic', agencies='USGS')

#order by comments close date
x <- fr_search(term='fisheries', per_page=100, order='newest', fields='comments_close_on')
dates <- paste(x$results$comments_close_on)
sort(dates[which(dates!='NA')], decreasing=TRUE)

#issue 1: these dates do not correspond to the dates on the dashboard
#(http://intouchanalytics.com/federal-register)
#it may be that a lot of the recent days are showing up as NA

#issue 2: some of the titles currently on the dashboard doesn't show up here.
x <- fr_search(term='fisheries')
paste(unique(x$results$title))
