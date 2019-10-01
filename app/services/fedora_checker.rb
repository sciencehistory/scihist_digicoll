class FedoraChecker
  def initialize(file_path)
    json = File.new(file_path, 'r')
    @data = Yajl::Parser.new.parse(json)
    @checked_works = []
    @checked_assets = []
    @fedora_host_and_port = "http://35.173.191.206:8080"
    fedora_credentials = ScihistDigicoll::Env.lookup(:import_fedora_auth)
    unless fedora_credentials
      puts "No fedora credentials available."
      return
    end
    @fedora_username,  @fedora_password = fedora_credentials.split(':')
  end

  """
  For each item in @contents, we're going to download its JSON from fedora.
  Depending on its hasModel, we will process it in a different way.
  """
  def check
    @contents = @data[0]["http://www.w3.org/ns/ldp#contains"].
      map { |cs| cs["@id"].gsub(/^.*\/fedora\/rest\/prod\//, '') }

    # sample = @contents
    sample = @contents[0..1000]
    sample.each do |fedora_id|
      dispatch_item(fedora_id)
    end
  end

  private

  def local_item(url)
    Kithe::Model.find_by_friendlier_id(url.gsub(/^.*\//, ''))
  end

  def fedora_connection
    @fedora_connection ||= begin
      conn = Faraday.new(@fedora_host_and_port, headers: { 'Accept' => 'application/ld+json' })
      conn.basic_auth(@fedora_username, @fedora_password)
      conn
    end
  end

  # Checks one item against Fedora.
  def dispatch_item(fedora_id)
    response = fedora_connection.get('/fedora/rest/prod/' + fedora_id).body
    obj = Yajl::Parser.new.parse(response)[0]
    model = obj["info:fedora/fedora-system:def/model#hasModel"][0]["@value"]
    if ['FileSet', 'GenericWork'].include? model
      item = local_item(obj['@id'])
      if item.nil?
        puts "ERROR: Missing #{model} in destination for #{obj['@id']}"
        return
      end
      if model == 'GenericWork'
        unless item.is_a? Work
          puts "ERROR: Mismatched model in destination. #{model} in source, #{item.type} in destination."
          return
        end
        FedoraItemChecker.new(obj, item, fedora_connection, @fedora_host_and_port).check_generic_work
        @checked_works << item.friendlier_id
      elsif model == 'FileSet'
        unless item.is_a? Asset
          puts "ERROR: Mismatched model in destination. #{model} in source, #{item.type} in destination."
          return
        end
        FedoraItemChecker.new(obj, item, fedora_connection, @fedora_host_and_port).check_file_set
        @checked_assets << item.friendlier_id
      end
    end
  end
end