if(! file.exists('obsoleteRows.csv')){
    message('No rows to delete. Taking no action.')
} else {

    #read in rows to delete
    obsRows = read.csv('obsoleteRows.csv', stringsAsFactors=FALSE)

    message(paste('Removing', nrow(obsRows), 'outdated records from Google Sheet.'))

    #load google sheet
    regDash_deets = googlesheets4::gs4_find('regDash')

    #delete rows
    for(i in seq_len(nrow(obsRows))){
        googlesheets4::range_delete(ss = regDash_deets$id,
                                    sheet = 1,
                                    # range = 2:3)
                                    range = as.character(obsRows[i, ]))
    }
}
