#Federal Register API v3 R client
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 1/22/17

#install packages if neccesary
if (!require("httr")) install.packages("httr")
if (!require("jsonlite")) install.packages("jsonlite")

library(httr)
library(jsonlite)

#regSearch() is rudimentary for now, but look through the comments to get a feel for it.
#adapted from federalregister::fr_search()

regSearch <- function(title=NULL, topic=NULL, agency=NULL){

    #every call to the federal register API starts with the baseURL below.
    #the long string of numbers and letters is a personal API key tied to my email address
    baseURL <- paste0('https://api.data.gov/regulations/v3/documents.json?api_key',
                      '=bwsoRB0l0VXMHpGvQrpbbcT6znsMl6qAT9QjEAZg')

    #if agency or topic keywords are specified, they will be given their proper
    #API tags here. I still see no obvious way to search title text only.
    if(!(is.null(agency))) agency <- paste0('&a=', agency)
    if(!(is.null(topic))) topic <- paste0('&s=', topic)

    #then those tags and keywords get appended to the API call
    fullURL <- paste0(baseURL, topic, agency, '&cs=15')

    #then we fetch the appropriate "entity" at the url requested...
    r <- GET(fullURL)

    #parse it into JSON format
    response <- content(r, as="text", encoding='UTF-8')

    #and translate the JSON into an R list
    out <- fromJSON(response)

    return(out)
}

x <- regSearch(topic='fisheries', agency='NOAA')

x$documents$title[1:5] #first five titles returned
x$documents$commentDueDate[1:5] #first five comment close dates returned

#there are 20 items returned per page, by default, but that and tons of other stuff is
#customizable. visit http://regulationsgov.github.io/developers/console/
#and click on the GET that lets you "search for documents". Enter my API key there and
#play around to see how the API composes various requests.
