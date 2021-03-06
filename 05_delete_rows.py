from __future__ import print_function
from __future__ import unicode_literals
from __future__ import division
from __future__ import absolute_import

from builtins import str
from builtins import open
from future import standard_library
standard_library.install_aliases()
import httplib2
import os
import sys
from pprint import *
import pandas as pd

from apiclient import discovery
from oauth2client import client
from oauth2client import tools
from oauth2client.file import Storage

try:
    import argparse
    flags = argparse.ArgumentParser(parents=[tools.argparser]).parse_args()
except ImportError:
    flags = None

# If modifying these scopes, delete your previously saved credentials
# at ~/.credentials/sheets.googleapis.com-python-quickstart.json
SCOPES = 'https://www.googleapis.com/auth/spreadsheets'
CLIENT_SECRET_FILE = 'client_secret.json'
APPLICATION_NAME = 'regDash'


def get_credentials():
    """Gets valid user credentials from storage.

    If nothing has been stored, or if the stored credentials are invalid,
    the OAuth2 flow is completed to obtain the new credentials.

    Returns:
        Credentials, the obtained credential.
    """
    home_dir = os.path.expanduser('~')
    credential_dir = os.path.join(home_dir, '.credentials')
    if not os.path.exists(credential_dir):
        os.makedirs(credential_dir)
    credential_path = os.path.join(credential_dir,
                                   'sheets.googleapis.com-python-quickstart.json')

    store = Storage(credential_path)
    credentials = store.get()
    if not credentials or credentials.invalid:
        flow = client.flow_from_clientsecrets(CLIENT_SECRET_FILE, SCOPES)
        flow.user_agent = APPLICATION_NAME
        if flags:
            credentials = tools.run_flow(flow, store, flags)
        else: # Needed only for compatibility with Python 2.6
            credentials = tools.run(flow, store)
        print('Storing credentials to ' + credential_path)
    return credentials

def main():
    credentials = get_credentials()
    http = credentials.authorize(httplib2.Http())
    discoveryUrl = ('https://sheets.googleapis.com/$discovery/rest?'
                    'version=v4')
    service = discovery.build('sheets', 'v4', http=http,
                              discoveryServiceUrl=discoveryUrl)

    spreadsheetId ='1YdLB2aG-FDEESytVGfHapTixMNcdVi2BZ6pf-IOO1UQ'

    #to get information about the sheet:
    #request = service.spreadsheets().get(spreadsheetId=spreadsheetId)#, ranges=ranges, includeGridData=include_grid_data)
    #response = request.execute()
    #pprint(response)

    #exit if no rows to delete
    if os.stat('obsoleteRows.csv').st_size == 0:
        print('No rows to delete. Taking no action.')
        sys.exit()

    #read in rows to delete
    obsRows = pd.read_csv('obsoleteRows.csv', header=None).values.T[0]

    # delete rows
    print('Removing ' +str(len(obsRows))+ ' outdated records from Google Sheet.')

    count = list(range(len(obsRows)))
    requests = []
    for i in count:
        x = obsRows[i].item() #convert from int64 to int
        requests.append({
            'deleteDimension': {
                'range': {
                    "sheetId": 1793980318,
                    "dimension": "ROWS",
                    "startIndex": x-count[i],
                    "endIndex": x-count[i]+1 #header is row 1 on Sheets
                }
            }
        })

    body = {
        'requests': requests
    }

    #make request
    response = service.spreadsheets().batchUpdate(spreadsheetId=spreadsheetId,
                                                  body=body).execute()

if __name__ == '__main__':
    main()

