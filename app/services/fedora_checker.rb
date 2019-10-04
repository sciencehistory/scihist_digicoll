class FedoraChecker
  def initialize(options:)
    @options = options
    File.open(options[:metadata_path], 'r') do |f|
      @data = Yajl::Parser.new.parse(f)
    end
    @checked_items = {}
  end

  """
  For each item in @contents, we're going to download its JSON from fedora.
  Depending on its hasModel, we will process it in a different way.
  """
  def check

    # @contents = ['4f/16/c2/91/4f16c291q']
    # @contents = ['dr/26/xz/12/dr26xz126']

    unless defined?(@contents)
      @contents = @data[0]["http://www.w3.org/ns/ldp#contains"].
        map { |cs| cs["@id"].gsub(/^.*\/fedora\/rest\/prod\//, '') }
    end

    if @contents && @contents&.length > 10
      @progress_bar = ProgressBar.create(total: @contents.length, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    end

    @contents.each do |fedora_id|
      do_this_item = sift_fedora_id(fedora_id)
      dispatch_item(fedora_id) if do_this_item
      @progress_bar.increment if @progress_bar
    end


    # pp @checked_items
  end

  private

  # Only check roughly a certain percentage of the items.
  # Useful for testing.
  def sift_fedora_id(fedora_id)
    return true if @options[:percentage_to_check] == 100
    fedora_id.bytes[0..15].sum % 100 < @options[:percentage_to_check]
  end

  def local_item(url)
    Kithe::Model.find_by_friendlier_id(url.gsub(/^.*\//, ''))
  end

  def fedora_connection
    @fedora_connection ||= begin
      conn = Faraday.new(@options[:fedora_host_and_port], headers: { 'Accept' => 'application/ld+json' })
      conn.basic_auth(@options[:fedora_username], @options[:fedora_password])
      conn
    end
  end

  def log(str)
    if @progress_bar
      @progress_bar.log(str)
    else
      puts(str)
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
        log("MISSING: #{model} in destination for #{obj['@id'].gsub(/^.*prod\//, '')}")
        return
      end
      if model == 'GenericWork'
        unless item.is_a? Work
          log("MISMATCH: #{model} in source, #{item.type} in destination.")
          return
        end
        FedoraItemChecker.new(
          fedora_data: obj, local_item:item,
          fedora_connection:fedora_connection,
          progress_bar:  @progress_bar,
          options:@options
        ).check_generic_work

      elsif model == 'FileSet'
        unless item.is_a? Asset
          log(puts "MISMATCH: #{model} in source, #{item.type} in destination.")
          return
        end
        FedoraItemChecker.new(
          fedora_data: obj, local_item:item,
          fedora_connection:fedora_connection,
          progress_bar:  @progress_bar,
          options:@options
        ).check_file_set


      end
      unless item.nil?
        @checked_items[model] = [] unless @checked_items[model]
        @checked_items[model] << item.friendlier_id
      end
    end
  end
end