require 'open-uri'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'csv'
require 'google/apis/sheets_v4'

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

# Sample value for ScihistDigicoll::Env.lookup(:test_google_project_user_id): email address of a user created for this project.

module GoogleArtsAndCulture
  class SpreadsheetCreator

    APPLICATION_NAME = 'Science History Institute Digital Collections'
    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

    CREDENTIALS_PATH = Dir.home

    #csv_data is a Ruby array of arrays
    def create_google_sheet(csv_data)
      if csv_data.empty?
        puts "Empty metadata."
        return
      end
      spreadsheet = blank_spreadsheet
      authorized_service.update_spreadsheet_value(
        spreadsheet.spreadsheet_id,
        'Sheet1!A1:Z' + csv_data.length.to_s,
        Google::Apis::SheetsV4::ValueRange.new(values: csv_data),
        value_input_option: 'USER_ENTERED'
      )
      puts "Spreadsheet URL: #{spreadsheet.spreadsheet_url}"
    end

    private

    def authorize
      scope =  ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
      FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

      credentials_json_string = ScihistDigicoll::Env.lookup(:test_google_project_credentials)
      user_id =                 ScihistDigicoll::Env.lookup(:test_google_project_user_id)

      client_id = Google::Auth::ClientId.from_hash(JSON.parse(credentials_json_string))
      token_store = Google::Auth::Stores::FileTokenStore.new(file: File.join(Dir.home, '.credentials', "sheets.googleapis.com-ruby-csv.yaml"))
      authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
      credentials = authorizer.get_credentials(user_id)

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
        service.client_options.application_name = APPLICATION_NAME
        service.authorization = authorize
        service
      end
    end

    def blank_spreadsheet
      spreadsheet_properties = Google::Apis::SheetsV4::SpreadsheetProperties.new(title: "Metadata #{DateTime.now.strftime("%Y-%m-%d %H:%M:%S")}")
      spreadsheet = Google::Apis::SheetsV4::Spreadsheet.new(properties: spreadsheet_properties)
      authorized_service.create_spreadsheet(spreadsheet, fields: 'spreadsheetId,spreadsheetUrl')
    end

  end
end