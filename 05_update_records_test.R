#Federal Register Project
#Data write script
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 3/12/17
rm(list=ls()); cat('\014') #clear everything

#INSTRUCTIONS:
#set the working directory to the place where you want to store a CSV copy of current records
    setwd('C:/Users/Mike/Desktop/fr_test')
    #03_functions.R should go in there. 04_update_records.R can go anywhere.
    #Google Sheets cache information will also be stored there in a file called .httr-oauth
    #any old fedRegOut.csv files will now be obsolete, so you can delete those.
    #most recent search date will also be stored.
#choose search depth (days before today) for the first run
    deepSearch = 150
#choose depth to check every time, to capture late additions
    lookBack = 7 
#then source this file. Nothing else needs to be edited, but feel free to customize.

#TROUBLESHOOTING ON WINDOWS
#if you get curl error: "Operation was aborted by an application callback", update devtools with:
    #remove.packages('devtools'); install.packages('devtools')
#if you get curl error: "Stream error in the HTTP/2 framing layer", update curl with:
    #install.packages("https://github.com/jeroen/curl/archive/master.tar.gz", repos = NULL)
    #(you'll need to have Rtools installed)

#start timing
ptm = proc.time()

#install packages if necessary
package_list = c('httr','jsonlite','stringr','plyr','dplyr','googlesheets')
new_packages = package_list[!(package_list %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)

#load all packages
for(i in c(package_list)) library(i, character.only=TRUE)

#load helper functions
source('03_functions.R')

#read in stored records if possible
oldRegs = NULL #this will remain NULL if old records not found
if(file.exists('fedRegOut.csv')){
    oldRegs = read.csv('fedRegOut.csv')
    message('Old records loaded')
    noRecords = FALSE
} else noRecords = TRUE

#get today's date as formatted string
todayRaw = Sys.Date()
today = format.Date(todayRaw, format='%m/%d/%y', tz='PST')

#if no records found or last run unknown, assign deepSearch days before today as the last run date.
#this should ensure that no open comment periods are omitted
noPrevRun = !(file.exists('dash_lastRun.txt'))
if(noPrevRun | noRecords){
    startDate = format.Date(todayRaw-deepSearch, format='%m/%d/%y', tz='PST')
    file.create('dash_lastRun.txt')
    conn = file('dash_lastRun.txt')
    writeLines(startDate, conn)
    close(conn)
    if(noPrevRun & !noRecords){
        message(paste('No record of last run found. Setting start date to ',startDate,'.'))
    } else {
        message(paste0('No existing data found. Setting start date to ',startDate,'.'))
    }
}

#otherwise, load the last run date and decrement by lookBack to grab potential late entries
conn = file('dash_lastRun.txt')
lastRun = readLines(conn) #read it
if(!noPrevRun & !noRecords){
    startDate = as.Date(lastRun, format='%m/%d/%y', tz='PST')-lookBack #subtract a week
    startDate = format.Date(startDate, format='%m/%d/%y') #reformat
}
writeLines(today, conn) #overwrite file with today's date
close(conn)

#get new records
if(noPrevRun | noRecords){
    message(paste('Retrieving records. This may take a few minutes'))
} else {
    message(paste0('Last run date: ',lastRun,'. (Re)retrieving records published after ',startDate,'.'))
}
span = as.numeric(todayRaw - as.Date(startDate, format='%m/%d/%y', tz='PST'))
nchunks = ceiling(span/30)
newRegs = NULL
if(nchunks > 1){
    for(i in nchunks:1){
        chunkStart = format.Date(todayRaw-(i*30), format='%m/%d/%y', tz='PST') #NOTICE: ends up grabbing more than deepSearch records
        chunkEnd = format.Date(todayRaw-((i-1)*30), format='%m/%d/%y', tz='PST')
        newRegs = rbind.fill(newRegs, regSearch1(start=chunkStart, end=chunkEnd))
    }
} else {
    newRegs = rbind.fill(newRegs, regSearch1(start=startDate, end=today))
}

#combine records
allRegs = rbind.fill(oldRegs, newRegs)

#remove duplicates, unusable records, and those closed for comment
dups = duplicated(paste(allRegs$title, allRegs$comment_url))
allRegs = filter(allRegs, comments_close_on != '', !dups,
                 as.Date(comments_close_on,format='%m/%d/%Y',tz='PST') > todayRaw)

#write all records to local file
write.csv(allRegs, 'fedRegOut.csv', row.names=FALSE)

#update google sheet. docs recommend delete-rewrite as the fastest method,
#but it's worth testing gs_edit_cells() and gs_add_row().
# message('Updating Google Sheets. Authorize in browser if this is first run.')
# if('fedRegDash' %in% gs_ls()$sheet_title){
#     dash = gs_title('fedRegDash')
#     gs_delete(dash)
# }

#create google sheet if this is first run
if(!'regDash' %in% gs_ls()$sheet_title){
    message('Creating new Google Sheet. Populating with all records.')
    gs_upload('fedRegOut.csv', sheet_title='regDash')
    # dash = gs_new('fedRegDash', input=allRegs, trim=TRUE, verbose=FALSE)
}

#update google sheet with new records
dash = gs_title('regDash')
gs_edit_cells(dash, input=allRegs, trim=TRUE)
dash = gs_ws_rename(dash, from='regDash', to='temp')
dash = gs_ws_new(dash, ws_title='regDash', input=allRegs, trim=TRUE, verbose=FALSE)
dash = gs_ws_delete(dash, ws='temp')


runTime = proc.time() - ptm
message(paste('Run completed in',round(runTime[3]/60,2),'minutes.'))
