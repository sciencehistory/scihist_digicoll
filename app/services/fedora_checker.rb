require "byebug"

class FedoraChecker
  def initialize(options:)
    @options = options

    # This file contains a long list of Fedora ids and little else.
    @data = JSON.parse(File.read(options[:metadata_path]))
    @checked_items = {}
  end

  """
  For each item in @contents, we're going to download its JSON from fedora.
  Depending on its hasModel, we will process it in a different way.
  """
  def check
    unless defined?(@contents)
      @contents = @data[0]["http://www.w3.org/ns/ldp#contains"].
        map { |cs| cs["@id"].gsub(/^.*\/fedora\/rest\/prod\//, '') }
      @data = nil # no need for the full data after this.
    end

    if @contents&.length > 10
      @progress_bar = ProgressBar.create(total: @contents.length, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    end

    @contents.each do |fedora_id|
      do_this_item = sift_fedora_id(fedora_id)
      dispatch_item(fedora_id) if do_this_item
      @progress_bar.increment if @progress_bar
    end

    # STATISTICS:
    if @options[:percentage_to_check] == 100 && @contents&.length > 100
      ['GenericWork', 'FileSet', 'Collection'].each do |type|
        kithe_ids = all_kithe_frienldier_ids(type)
        log """#{type}s in FEDORA but not in KITHE:
        #{@checked_items[type] - kithe_ids}"""
        log """#{type}s in KITHE but not in FEDORA:
        #{kithe_ids - @checked_items[type]}"""
      end
    else
      log "Not running stats; didn't request all items be checked."
    end
  end

  private


  # Fetch all Kithe friendlier_ids of a given type.
  # We're not interested in collection thumb assets;
  # these didn't exist in Sufia anyway.
  def all_kithe_frienldier_ids(type)
    klass = lookup_target_class(type)
    klass = klass.where.not(type:'CollectionThumbAsset') if type == 'FileSet'
    klass.pluck(:friendlier_id)
  end

  # Only check roughly a certain percentage of the items.
  # Useful for testing.
  def sift_fedora_id(fedora_id)
    return true if @options[:percentage_to_check] == 100
    return true if @contents&.length < 10
    fedora_id.bytes[0..15].sum % 100 < @options[:percentage_to_check]
  end

  def local_item(url)
    Kithe::Model.readonly.find_by_friendlier_id(url.gsub(/^.*\//, ''))
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

  def lookup_target_class(source_class)
    {
      'GenericWork' => Work,
      'FileSet' => Asset,
      'Collection' => Collection
    }[source_class]
  end

  # Checks one item against Fedora.
  def dispatch_item(fedora_id)
    response = fedora_connection.get('/fedora/rest/prod/' + fedora_id).body
    fedora_data = JSON.parse(response)[0]
    model = fedora_data["info:fedora/fedora-system:def/model#hasModel"][0]["@value"]
    target_class = lookup_target_class(model)
    return if target_class.nil?

    kithe_item = local_item(fedora_data['@id'])

    fedora_id = fedora_data['@id'].gsub(/^.*prod\//, '')
    friendlier_id = fedora_data['@id'].gsub(/^.*\//, '')

    @checked_items[model] = [] unless @checked_items[model]
    @checked_items[model] << friendlier_id

    if kithe_item.nil?
      log("""MISSING: #{model} in destination
      for #{fedora_id}""")
      return
    end

    unless kithe_item.is_a? target_class
      log("""MISMATCH: #{model} in source, #{kithe_item.type}
        in destination for
        #{fedora_id}""")
      return
    end

    FedoraItemChecker.new(
      fedora_data:       fedora_data,
      local_item:        kithe_item,
      fedora_connection: fedora_connection,
      progress_bar:      @progress_bar,
      options:           @options
    ).check(target_class)
  end
end