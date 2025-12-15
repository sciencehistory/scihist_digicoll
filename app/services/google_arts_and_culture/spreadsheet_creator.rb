require 'open-uri'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'csv'

# can I do it without this???
#require 'google/apis/sheets_v4'


module GoogleArtsAndCulture
  class SpreadsheetCreator

    APPLICATION_NAME = 'Google Arts and Culture' #is this arbitrary?
    OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

    def authorize
      scope =  ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']


      FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

      credentials_json_string = ScihistDigicoll::Env.lookup(:google_arts_and_culture_credentials)
      credentials_io =          StringIO.new(credentials_json_string)
      client_id = Google::Auth::ClientId.from_file(credentials_io)

      # create a token scope
      token_store = Google::Auth::Stores::FileTokenStore.new(file: File.join(Dir.home, '.credentials', "sheets.googleapis.com-ruby-csv.yaml"))
      authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)

      user_id = 'default'
      credentials = authorizer.get_credentials(user_id)

      if credentials.nil?
        url = authorizer.get_authorization_url(base_url: OOB_URI)
        puts "Open the following URL in your browser and authorize the app:"
        puts url
        print 'Enter the authorization code: '
        code = gets.chomp
        credentials = authorizer.get_and_store_credentials_from_code(user_id, code, base_url: OOB_URI)
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
      spreadsheet_properties = Google::Apis::SheetsV4::SpreadsheetProperties.new(title: 'Metadata')
      spreadsheet = Google::Apis::SheetsV4::Spreadsheet.new(properties: spreadsheet_properties)
      authorized_service.create_spreadsheet(spreadsheet, fields: 'spreadsheetId,spreadsheetUrl')
    end


    #csv_data is a Ruby array of arrays
    def update_spreadsheet (csv_data)
      if csv_data.empty?
        puts "Empty metadata."
        return
      end

      spreadsheet_id = blank_spreadsheet.spreadsheet_id
      puts "Created new spreadsheet with ID: #{spreadsheet_id}"
      puts "URL: #{created_spreadsheet.spreadsheet_url}"

      range = 'Sheet1!A1:Z' + csv_data.length.to_s
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: csv_data)

      authorized_service.update_spreadsheet_value(
        spreadsheet_id,
        range,
        value_range,
        value_input_option: 'USER_ENTERED'
      )
    end
  end
end