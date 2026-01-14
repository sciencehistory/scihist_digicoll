require 'open-uri'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'csv'
require 'google/apis/sheets_v4'


# Upload an arbitrary Ruby array of arrays to a Google spreadsheet in your Google Docs account, as a convenience.
# Once this is set up, a user no longer has to download the Google Arts and Culture metadata from a 
#
# See https://github.com/sciencehistory/scihist_digicoll/pull/3222 for more context.
# Requires two ENV settings:
#   1) the Google Docs user id (usually a person's email address like erubeiz)
#   2) credentials for a Google Project with permissions that allow you to upload a spreadsheet.
#
#
#
# How to use:
# 1: extract the Google Arts and Culture metadata from a scope
#
# scope =  Work.all.includes(:leaf_representative)
# metadata = GoogleArtsAndCulture::Exporter.new(scope).metadata
# GoogleArtsAndCulture::SpreadsheetCreator.new.create_google_sheet(csv_data: csv_data, title: "Metadata #{DateTime.now.strftime("%Y-%m-%d %H:%M:%S")}")
#
#
# Sample value for ScihistDigicoll::Env.lookup(:test_google_project_credentials)
# {
#   "installed": {
#     "client_id": "BLABLABLA.apps.googleusercontent.com",
#     "project_id": "BLABLABLA",
#     "auth_uri": "https://accounts.google.com/o/oauth2/auth",
#     "token_uri": "https://oauth2.googleapis.com/token",
#     "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
#     "client_secret": "BLABLABLA",
#     "redirect_uris": [
#       "http://localhost"
#     ]
#   }
# }
#
# Sample value for ScihistDigicoll::Env.lookup(:test_google_project_user_id): email address of a user created for this project.
#
#
module GoogleArtsAndCulture
  class SpreadsheetCreator


    # TODO: 
    #       change the name of the credentials env vars to better distinguish them from the google arts and culture project credentials
    #           from test_google_project_credentials to google_sheets_credentials
    #           from  test_google_project_user_id    to google_sheets_user_id

    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

    # A directory in which to put the credentials file:
    CREDENTIALS_PATH = Dir.home

    def initialize(csv_data:, title:)
      @title = title
      @csv_data = csv_data
      if @csv_data.empty? || @title.empty?
        puts "Please supply data and a title."
      end
      #csv_data is a Ruby array of arrays
      unless @csv_data.is_a?(Array) && @csv_data.all? { |row| row.is_a?(Array) }
        puts "Please supply an array of rows to put in the spreadsheet."
      end
    end

    # Create a blank spreadsheet, put the data into it, and return its URL.
    def google_sheet_url
      spreadsheet = blank_spreadsheet
      if spreadsheet.nil?
        puts "Unable to create a blank spreadsheet."
        return
      end
      
      cloud_service = authorized_service
      if service.nil?
        puts "Unable to create an authorized Google Cloud service."
        return
      end

      cloud_service.update_spreadsheet_value(
        spreadsheet.spreadsheet_id,
        'Sheet1!A1:Z' + @csv_data.length.to_s,
        Google::Apis::SheetsV4::ValueRange.new(values: @csv_data),
        value_input_option: 'USER_ENTERED'
      )

      return spreadsheet.spreadsheet_url
    end

    private


    def application_name
      'Science History Institute Digital Collections'
    end

    def authorize
      scope =  ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
      FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

      credentials_json_string = ScihistDigicoll::Env.lookup(:test_google_project_credentials)
      user_id =                 ScihistDigicoll::Env.lookup(:test_google_project_user_id)

      client_id = Google::Auth::ClientId.from_hash(JSON.parse(credentials_json_string))

      # Store the token in a local file:
      token_store = Google::Auth::Stores::FileTokenStore.new(file: File.join(Dir.home, '.credentials', "sheets.googleapis.com-ruby-csv.yaml"))
      authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
      credentials = authorizer.get_credentials(user_id)


      # This would need its own prompt in the UI; not sure how to handle it.
      if credentials.nil?
        url = authorizer.get_authorization_url(base_url: OOB_URI)
        puts "Open the following URL in your browser and authorize the app:"
        puts url
        print 'Enter the authorization code: '
        code = gets.chomp
        credentials = authorizer.get_and_store_credentials_from_code(user_id: user_id, code: code, base_url: OOB_URI)
      end
      credentials
    end

    def authorized_service
      @authorized_service ||= begin
        service = Google::Apis::SheetsV4::SheetsService.new
        service.client_options.application_name = application_name
        service.authorization = authorize
        service
      end
    end

    def blank_spreadsheet
      properties  = Google::Apis::SheetsV4::SpreadsheetProperties.new(title: @title)
      spreadsheet = Google::Apis::SheetsV4::Spreadsheet.new(properties: properties)
      begin
        authorized_service.create_spreadsheet(spreadsheet, fields: 'spreadsheetId,spreadsheetUrl')
      rescue Google::Auth::AuthorizationError => e
        puts "Encountered an error while trying to create a blank spreadsheet: #{e.to_s}"
      end
    end

  end
end