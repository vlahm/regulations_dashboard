#Microbenchmarking federal register search methods
#Author: Zach Koehn
#Contact: zkoehn@gmail.com
#Creation Date: 2/27/2017
# Detail: method to search for fastest way to append particularly long search queries


#install packages if necessary
if (!require("httr")) install.packages("httr")
if (!require("jsonlite")) install.packages("jsonlite")
if (!require("stringr")) install.packages("stringr")
if (!require("data.table")) install.packages("data.table")

library(plyr)
library(data.table)
library(httr)
library(jsonlite)
library(stringr)
library(doMC)
registerDoMC(cores=2)

#regEngine processes user input and generates a proper API call.
#not used directly. called by regSearch1
regEngine1 <- function(topic=NULL, agency=NULL, start=NULL, end=NULL, doc_type='ALL', PAGE){
  
  #this base url includes the API expressions for number of items per page, sort by oldest,
  #and all the fields to return.
  baseURL <-
    paste0('www.federalregister.gov/api/v1/documents.csv?fields%5B%5D=action&fields%5B%5D',
           '=agency_names&fields%5B%5D=comment_url&fields%5B%5D=comments_close_on&fields%',
           '5B%5D=effective_on&fields%5B%5D=html_url&fields%5B%5D=pdf_url&fields%5B%5D=pu',
           'blication_date&fields%5B%5D=significant&fields%5B%5D=signing_date&fields%5B%5',
           'D=title&fields%5B%5D=topics&per_page=1000&order=oldest')
  
  #if arguments are specified, they will be given their proper API tags here.
  if(!(is.null(agency))) agency <- paste0('&conditions%5Bagencies%5D%5B%5D=', agency)
  if(!(is.null(topic))) topic <- paste0('&conditions%5Bterm%5D=', topic)
  if(doc_type=='ALL') type<-NULL else type<-paste0('&conditions%5Btype%5D%5B%5D=', doc_type)
  if(!(is.null(start))){
    date <- str_match(start, '(\\d+)/(\\d+)/(\\d+)')[2:4]
    start <- paste0('&conditions%5Bpublication_date%5d%5Bgte%5D=',
                    date[1],'%2F',date[2],'%2F',date[3])
  }
  if(!(is.null(end))){
    date <- str_match(end, '(\\d+)/(\\d+)/(\\d+)')[2:4]
    end <- paste0('&conditions%5Bpublication_date%5d%5Blte%5D=',
                  date[1],'%2F',date[2],'%2F',date[3])
  }
  
  #the page to return is controlled by regSearch1() which wraps this function
  pg <- paste0('&page=', PAGE)
  
  #then those tags and keywords get appended to the API call
  fullURL <- paste0(baseURL, pg, agency, topic, type, start, end)
  
  #then we fetch the appropriate "entity" at the url requested...
  r <- GET(fullURL)
  
  #parse it into CSV format and read it
  response <- content(r, as="text", encoding='UTF-8')
  out <- read.csv(text=response, stringsAsFactors=FALSE)
  
  return(out)
}

#main function for searching federal register, calls regEngine1 function above
regSearch1 <- function(topic=NULL, agency=NULL, start=NULL, end=NULL, doc_type='ALL'){
  
  #return the first page of results (the API can return max=1000 per page)
  PAGE <- 1
  x <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
  
  #as long as 1000 results are returned, grab another page
  while(nrow(x) %% 1000 == 0){
    PAGE <- PAGE+1
    y <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
    x <- rbind(x, y) #note this may become slow with larger numbers of results, 
    # regSearch2  below uses the same script but likely faster method to bind 
    # search result rows
  }
  return(x)
}


#agency must be specified like: 'central-intelligence-agency'.
#start and end (oldest and most recent publication dates) must be: 'MM/DD/YY'.
#start and end do not need to be supplied together.
#doc_type must be one of 'RULE', 'PRORULE' (proposed rule), 'NOTICE',
#'PRESDOCU' (presidential document), or 'ALL'.
out <- regSearch1(topic='fisheries', agency='national-oceanic-and-atmospheric-administration',
                  start='01/02/16', end='02/25/17', doc_type='ALL')


#write output
setwd('set this') #would be nice to automatically write to the containing directory
write.csv(out, 'fedRegOut.csv', row.names=FALSE) #write.csv() writes to w/e directory is open.. might not be necessary to include setwd() above





#testing alternatives to rbind version above that use purportedly faster calls 
#with some funcitonality as rbind
# using {plyr} rbind.fill
regSearch2 <- function(topic=NULL, agency=NULL, start=NULL, end=NULL, doc_type='ALL'){
  
  #return the first page of results (the API can return max=1000 per page)
  PAGE <- 1
  x <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
  
  #as long as 1000 results are returned, grab another page
  while(nrow(x) %% 1000 == 0){
    PAGE <- PAGE+1
    y <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
    x <- rbind.fill(x, y)
  }
  return(x)
}



# using {data.table} rbindlist, evidently the fastest
regSearch3 <- function(topic=NULL, agency=NULL, start=NULL, end=NULL, doc_type='ALL'){
  
  #return the first page of results (the API can return max=1000 per page)
  PAGE <- 1
  x <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
  
  #as long as 1000 results are returned, grab another page
  while(nrow(x) %% 1000 == 0){
    PAGE <- PAGE+1
    y <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
    x <- rbindlist(list(x, y),use.names = T,fill=F)
  }
  return(x)
}



#test with a larger sample of ALL topics regarding agency=NOAA from 2013-today(2/24/2017)
out1.rbind <- regSearch1(topic=NULL, agency='national-oceanic-and-atmospheric-administration',
                         start='01/02/13', end='02/25/17', doc_type='ALL')
out2.rbind.fill <- regSearch2(topic=NULL, agency='national-oceanic-and-atmospheric-administration',
                              start='01/02/13', end='02/25/17', doc_type='ALL')

out3.rbindlist <- regSearch3(topic=NULL, agency='national-oceanic-and-atmospheric-administration',
                             start='01/02/13', end='02/25/17', doc_type='ALL')

#test to see if edited versions are faster, microbenchmarking
library(microbenchmark)
library(ggplot2)
mb.test <- microbenchmark(
  out1.rbind,
  out2.rbind.fill,
  out3.rbindlist,
  times = 1e5
)
mb.test
autoplot(mb.test)

#over a number of benchmarks, rbind.fill from {plyr} is the fastest, 
