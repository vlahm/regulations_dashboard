#delete relay file 1
x = file.remove('obsoleteRows.csv')

#read all current records back in, as well as vector of rows to append
newRegs = read.csv('newRegs.csv', stringsAsFactors=FALSE)

#load google sheet
regDash_deets = googlesheets4::gs4_find('regDash')

#append new rows to the goog sheet
nRegs = nrow(newRegs)
if(nRegs == 0){
    message('No new records to add. Taking no action.')
} else {
    message(paste0('Appending ', nRegs, ' new records to Google Sheet.'))


    #break large sets into chunks because gs_add_row fails when it gets overwhelmed
    nchunks = ceiling(nRegs/100)
    for(i in 1:nchunks){
        newStart = (i-1)*100+1
        if(i == nchunks){
            newEnd = nchunks*100 - (nchunks*100 - nRegs)
        } else {
            newEnd = i*100
        }
        googlesheets4::sheet_append(ss = regDash_deets$id,
                                    data = newRegs[newStart:newEnd,],
                                    sheet = 1)
    }
}

#delete relay file 2
x = file.remove('newRegs.csv')

#verify that the new stored records are identical to the updated google sheet
# updated = gs_read(dash)
# if(!identical(updated, allRegs)){
#     message(writeLines(paste0('Google Sheet disagrees with local CSV.\n',
#                              'Try rerunning 04_, 05_, and 06_ scripts.\n',
#                              'If you get this message again, call Mike.')))
# }
