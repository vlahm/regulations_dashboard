#Federal Register Project
#Federal Register API v1 R client functions
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 1/25/17

#define regEngine1, for generating API calls and structures output.
regEngine1 <- function(topic=NULL, agency=NULL, start=NULL, end=NULL, doc_type='ALL', PAGE){

    #this base url includes the API expressions for number of items per page, sort by oldest,
    #and all the fields to return.
    baseURL <-
        paste0('www.federalregister.gov/api/v1/documents.csv?fields%5B%5D=action&fields%5B%5D',
               '=agency_names&fields%5B%5D=comment_url&fields%5B%5D=comments_close_on&fields%',
               '5B%5D=effective_on&fields%5B%5D=html_url&fields%5B%5D=pdf_url&fields%5B%5D=pu',
               'blication_date&fields%5B%5D=signing_date&fields%5B%5D=title&fields%5B%5D=topi',
               'cs&fields%5B%5D=abstract&per_page=1000&order=oldest')

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

#define regSearch1, for combining results and calling regEngine1.
    #agency argument format: 'central-intelligence-agency'.
    #start and end date format: 'MM/DD/YY'.
    #start and end do not need to be supplied together.
    #doc_type must be one of 'RULE', 'PRORULE' (proposed rule), 'NOTICE',
    #'PRESDOCU' (presidential document), or 'ALL'.
regSearch1 <- function(topic=NULL, agency=NULL, start=NULL, end=NULL, doc_type='ALL'){

    #return the first page of results (the API can return max=1000 per page)
    PAGE <- 1
    x <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)

    #as long as 1000 results are returned, grab another page
    while(nrow(x) %% 1000 == 0){
        PAGE <- PAGE+1
        y <- regEngine1(topic=topic, agency=agency, start=start, end=end, doc_type=doc_type, PAGE)
        x <- rbind.fill(x, y) #slight change to speed up rbind (from regSearch_benchmarking.R)
    }
    return(x)
}
