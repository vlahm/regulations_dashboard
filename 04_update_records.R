#Federal Register Project
#Data write script
#Author: Mike Vlah
#Contact: vlahm13@gmail.com
#Creation Date: 3/12/17
rm(list=ls()); cat('\014') #clear everything

#INSTRUCTIONS:
#set the working directory to the place where you want to store a CSV copy of current records
    # setwd('C:/Users/Mike/git/regulations_dashboard')
    setwd('~/git/public_comment_project/regulations_dashboard')
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
# ptm = proc.time()

#install packages if necessary
package_list = c('httr','jsonlite','stringr','plyr','dplyr','googlesheets')#,'rPython')
new_packages = package_list[!(package_list %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)

#load all packages
for(i in c(package_list)) library(i, character.only=TRUE)

#load helper functions
source('03_functions.R')

#authorize tidyverse to communicate with google sheets
# googlesheets4::gs4_auth(path = 'regdash-cc3be28576b9.json')

# token = gs_auth()
# saveRDS(token, 'gs_token.rds')
# gs_auth(token=readRDS('gs_token.rds'))

#read in old records if possible
gsheets = googlesheets4::gs4_find()
remote_sheet_exists = 'regDash' %in% gsheets$name
if(remote_sheet_exists){
    sheetID = gsheets$id[gsheets$name == 'regDash']
    # dash = gs_title('regDash')
    oldRegs = googlesheets4::read_sheet(sheetID,
                                        col_types = 'cccccccccccc')
    oldRegs[is.na(oldRegs)] = ''
    message('Old records loaded.')
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

} else {

    #otherwise, load the last run date and decrement by lookBack to grab potential late entries
    conn = file('dash_lastRun.txt')
    lastRun = readLines(conn) #read it
    if(!noPrevRun & !noRecords){
        startDate = as.Date(lastRun, format='%m/%d/%y', tz='PST')-lookBack #subtract a week
        startDate = format.Date(startDate, format='%m/%d/%y') #reformat
    }
    writeLines(today, conn) #overwrite file with today's date
    close(conn)
}

#find range of records that are now obsolete and write their row indices to a file
# todayRaw = todayRaw+1 #for testing
if(! noRecords){
    message('Identifying obsolete records.')
    obsoleteRows = which(as.Date(oldRegs$comments_close_on,format='%m/%d/%Y',tz='PST') < todayRaw |
                               (oldRegs$comments_close_on == '' &
                                    as.Date(oldRegs$publication_date,format='%m/%d/%Y',tz='PST') < (todayRaw-89)))
    oldkey = paste(oldRegs$title, oldRegs$comment_url, oldRegs$pdf_url)
    obsoleteRows = append(obsoleteRows, which(duplicated(oldkey))) #just in case dupes end up in the system
    write.table(obsoleteRows, 'obsoleteRows.csv', row.names=FALSE, col.names=FALSE)
}

#get new records (some will be duplicates)
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

#remove duplicates, records closed for comment, and records missing comment close date that were published > 89 days ago
newkey = paste(newRegs$title, newRegs$comment_url, newRegs$pdf_url)
if(!noPrevRun & !noRecords){
    newRegs = newRegs[!newkey %in% oldkey,]
}
newRegs = newRegs %>%
    filter(as.Date(comments_close_on,format='%m/%d/%Y',tz='PST') >= todayRaw |
               (comments_close_on == '' &
                    as.Date(publication_date,format='%m/%d/%Y',tz='PST') >= (todayRaw-89)))

#update google sheet. docs recommend delete-rewrite as the fastest method
#deprecated: need sheet ID to remain the same
# message('Updating Google Sheets. Authorize in browser if this is first run.')
# if('fedRegDash' %in% gs_ls()$sheet_title){
#     dash = gs_title('fedRegDash')
#     gs_delete(dash)
# }

#create google sheet if this is first run
if(! remote_sheet_exists){
    message('Creating new Google Sheet. Populating with all records.')
    allRegs = rbind.fill(oldRegs, newRegs)
    # write.csv(allRegs, 'fedRegOut.csv', row.names=FALSE)
    googlesheets4::write_sheet(data = allRegs,
                               ss = sheetID,
                               sheet = 1)
    # dash = gs_new('fedRegDash', input=allRegs, trim=TRUE, verbose=FALSE)
}

# write new regs to a file
write.csv(newRegs, 'newRegs.csv', row.names=FALSE)

# message(writeLines(paste0('If this is not the first run-through, ',
#                          'source 05_delete_rows.py next.\nThen source 06_add_rows.R.')))

if(remote_sheet_exists){
    source('05_delete_rows.R')
    source('06_add_rows.R')
}

# runTime = proc.time() - ptm
# message(paste('Run completed in',round(runTime[3]/60,2),'minutes.'))
