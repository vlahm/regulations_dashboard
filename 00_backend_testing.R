#Federal Register API examples
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 12/7/16

#note: if print() fails with "$ operator is invalid for atomic vectors",
#use paste() or cat() instead

#setup

if (!require("curl")) install.packages("curl")
if (!require("devtools")) install.packages("devtools")

library(curl)
library(devtools)
install_github('rOpenGov/federalregister')
library(federalregister)


#topic search
x <- fr_search(term='fisheries', per_page=100, order='newest')
print(x$results$title[1:10]) #first ten titles by most recent
print(x$results$publication_date[1:10]) #dates
print(x$results$abstract[1]) #first abstract

#title search?

#not sure how to target specific document sections for keyword search. the 'term' argument seems to
#include both title and excerpt fields (maybe abstract too)

#agency search
x <- fr_search(term='arctic', agencies='USGS')

#order by comments close date
x <- fr_search(term='fisheries', per_page=100, order='newest', fields='comments_close_on')
dates <- x$results$comments_close_on
sort(dates[which(dates!='NA')], decreasing=TRUE)

#issue 1: these dates do not correspond to the dates on the dashboard
#(http://intouchanalytics.com/federal-register)
#it may be that a lot of the recent days are showing up as NA

#issue 2: some of the titles currently on the dashboard doesn't show up here.
x <- fr_search(term='fisheries', version='v4')
unique(x$results$title)


#other potentially useful functions
fr_get
pi_search
pi_get
pi_current
fr_agencies
