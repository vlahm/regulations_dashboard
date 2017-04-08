rm(list=ls()); cat('\014')
library(googlesheets)

#delete relay file 1
file.remove('obsoleteRows.csv')

#read all current records back in, as well as vector of rows to append
allRegs = read.csv('fedRegOut.csv', stringsAsFactors=FALSE)
newRows = as.vector(as.matrix(read.csv('newRows.csv', header=FALSE)))

#if there are ever gaps in the order of the new row indices, we'll have to make modifications
#this means we can't just append rows to the google sheet. instead we'll have to insert the new rows
#by index.
continuous = all(rle(newRows)$lengths == 1)
at_end = newRows[length(newRows)] == nrow(allRegs)

#append new rows to the goog sheet
if(continuous & at_end){
    message(writeLines(paste0('Appending ', length(newRows), ' new records to Google Sheet.\n',
                              'This will take about ', round(length(newRows)*2.5/60, 1), ' minutes.')))
    dash = gs_title('regDash')
    gs_add_row(dash, input=allRegs[newRows,], verbose=FALSE)

    #delete relay file 2
    file.remove('newRows.csv')
} else {
    message('Discontinuity in rows to append. Call Mike!')
}

#verify that the new stored records are identical to the updated google sheet
dash = gs_title('regDash')
newSheet = gs_read(dash)
if(!identical(newSheet, allRegs)){
    message('Google Sheet disagrees with local CSV. Call Mike!')
}
