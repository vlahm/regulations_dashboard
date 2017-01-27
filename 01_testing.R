#Federal Register API v3 R client
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 1/22/17

#it will help to collapse all folds (if using Rstudio):
#ALT+O on Windows and Linux, CMD+OPT+O on OSX

#install packages if neccesary
if (!require("httr")) install.packages("httr")
if (!require("jsonlite")) install.packages("jsonlite")
if (!require("stringr")) install.packages("stringr")

library(httr)
library(jsonlite)
library(stringr)

# federal register API v3 approach (abandoned) ####
#this could be useful for creating a listserv, but the v1 approach is essential
#for the dashboard, because it allows fetching of html and pdf versions of the regulations

regSearch3 <- function(topic=NULL, agency=NULL, comm_open=TRUE,
                      pub_range=NULL, doc_type='all'){

    #every call to the federal register API starts with the baseURL below.
    #the long string of numbers and letters is a personal API key tied to my email address
    baseURL <- paste0('https://api.data.gov/regulations/v3/documents.json?api_key',
                      '=bwsoRB0l0VXMHpGvQrpbbcT6znsMl6qAT9QjEAZg')

    #if arguments are specified, they will be given their proper
    #API tags here. I still see no obvious way to search title text only.
    if(!(is.null(agency))) agency <- paste0('&a=', agency)
    if(!(is.null(topic))) topic <- paste0('&s=', topic)
    if(!(is.null(pub_range))) pub_range <- paste0('&pd=', pub_range) #must be MM/DD/YY or
        #MM/DD/YY-MM/DD/YY
    if(comm_open) comm<-'&cp=O' else comm<-NULL
    if(doc_type=='all') type<-NULL else type<-paste0('&dct=', doc_type) #one of:
        #N (notice), PR (proposed rule), FR (rule), O (other), SR (supp. mat.), PS (public sub.)

    #then those tags and keywords get appended to the API call
    fullURL <- paste0(baseURL, topic, agency, comm, type, pub_range, '&rpp=1000')

    #then we fetch the appropriate "entity" at the url requested...
    r <- GET(fullURL)

    #parse it into JSON format
    response <- content(r, as="text", encoding='UTF-8')

    #and translate the JSON into an R list
    out <- fromJSON(response)

    return(out)
}

x <- regSearch3(topic='fisheries', agency='NOAA', pub_range='01/02/17-01/25/17', doc_type='all')

#first five returned titles
x$documents$title[1:5]

#to explore all possible request fields, visit
#http://regulationsgov.github.io/developers/console/
#and click on the 'GET 'that lets you "search for documents". Enter my API key there and
#play around to see how the API composes various requests.

# federal register API v1 approach ####

#agency must be specified like: 'central-intelligence-agency'.
#start and end (oldest and most recent publication dates) must be: 'MM/DD/YY'.
#start and end need not be supplied together.
#doc_type must be one of 'RULE', 'PRORULE' (proposed rule), 'NOTICE',
#'PRESDOCU' (presidential document), or 'ALL'.

#regEngine is not used directly. it's called by regSearch1
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

#main function for searching federal register
regSearch1 <- function(topic=NULL, agency=NULL, start=NULL, end=NULL, doc_type='ALL'){

    #return the first page of results (the API can return max=1000 per page)
    PAGE <- 1
    x <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)

    #as long as 1000 results are returned, grab another page
    while(nrow(x) %% 1000 == 0){
        PAGE <- PAGE+1
        y <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
        x <- rbind(x, y)
    }
    return(x)
}

out <- regSearch1(topic='fisheries', agency='national-oceanic-and-atmospheric-administration',
           start='01/02/17', end='01/25/17', doc_type='ALL')

#first five returned titles (different from those returned by v3 API)
out$title[1:5]
#number of records returned
nrow(out)

#it can be slow if the search is very broad:
out2 <- regSearch1(topic='security', start='01/01/16')
nrow(out2) #9865 records

#to explore all possible request fields, follow Mary's instructions in fedreg_extraction.docx,
#which in the "resources" folder in the Git repo.
