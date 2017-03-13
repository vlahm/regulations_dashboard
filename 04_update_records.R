#Federal Register Project
#Data write script
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 3/12/17

#TODO: upload/edit speed comparison
#auto authorization (?gs_auth; .httr-oauth)
#dedicated google account

#INSTRUCTIONS:
#set the working directory, to the place where you want to store regulation data.
setwd('~/temp')
#03_functions.R should go in there. 04_update_records.R can go anywhere.
#Google Sheets cache information will also be stored there as .httr-oauth
#any old fedRegOut.csv files will now be obsolete, so you can delete those.
#then source this file. Nothing else needs to be edited, but feel free to customize.

#clear everything and start timing
rm(list=ls()); cat('\014')
ptm <- proc.time()

#install packages if necessary
package_list <- c('httr','jsonlite','stringr','plyr','dplyr','googlesheets')
new_packages <- package_list[!(package_list %in% installed.packages()[,"Package"])]
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

#if no records found or last run unknown, assign 150 days before today as the last run date.
#this should ensure that no open comment periods are omitted
noPrevRun = !(file.exists('dash_lastRun.txt'))
if(noPrevRun | noRecords){
    startDate = format.Date(todayRaw-150, format='%m/%d/%y', tz='PST')
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

#otherwise, load the last run date and decrement by a week to grab potential late entries
conn = file('dash_lastRun.txt')
lastRun = readLines(conn) #read it
if(!noPrevRun & !noRecords){
    startDate = as.Date(lastRun, format='%m/%d/%y', tz='PST')-7 #subtract a week
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
span = todayRaw - as.Date(startDate, format='%m/%d/%y', tz='PST')
nchunks = ceiling(as.numeric(span)/30)
newRegs = NULL
for(i in nchunks:1){
    chunkStart = format.Date(todayRaw-(i*30), format='%m/%d/%y', tz='PST')
    chunkEnd = format.Date(todayRaw-((i-1)*30), format='%m/%d/%y', tz='PST')
    newRegs <- rbind.fill(newRegs, regSearch1(start=chunkStart, end=chunkEnd))
}

#combine records
allRegs = rbind.fill(oldRegs, newRegs)

#remove duplicates, unusable records, and those closed for comment
dups = duplicated(paste(allRegs$title, allRegs$comment_url))
allRegs = filter(allRegs, comments_close_on != '', comment_url != '', !dups,
                 as.Date(comments_close_on,format='%m/%d/%y',tz='PST') > todayRaw)

#write all records to local file
write.csv(allRegs, 'fedRegOut.csv', row.names=FALSE)

#update google sheet. docs recommend delete-rewrite as the fastest method,
#but it's worth testing gs_edit_cells() and gs_add_row().
message('Updating Google Sheets. Authorize in browser if this is first run.')
if('fedRegDash' %in% gs_ls()$sheet_title){
    dash = gs_title('fedRegDash')
    gs_delete(dash)
}
gs_upload('fedRegOut.csv', sheet_title='fedRegDash')

runTime = proc.time() - ptm
message(paste('Run completed in',round(runTime[3]/60,2),'minutes.'))

