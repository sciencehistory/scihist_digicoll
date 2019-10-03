class FedoraChecker
  def initialize(options:)
    @options = options
    @real = true
    if @real
      json = File.new(options[:metadata_path], 'r')
      @data = Yajl::Parser.new.parse(json)
    end
    @checked_items = {}
  end

  """
  For each item in @contents, we're going to download its JSON from fedora.
  Depending on its hasModel, we will process it in a different way.
  """
  def check
    if @real
      @contents = @data[0]["http://www.w3.org/ns/ldp#contains"].
        map { |cs| cs["@id"].gsub(/^.*\/fedora\/rest\/prod\//, '') }
    end

    sample = [
      #'bc/38/6j/33/bc386j33d',
      'm0/39/k5/32/m039k532d',
      # 's1/78/4m/31/s1784m313',
      # 'jd/47/2x/18/jd472x184',
      # 'k0/69/88/40/k0698840f',
      # 'pv/63/g1/30/pv63g130s',
      # '73/66/65/54/736665548',
      # 'dr/26/xz/12/dr26xz126',
    ]

    if @real
      # sample = @contents
      sample = @contents[0..2000]
    end

    sample.each do |fedora_id|
      dispatch_item(fedora_id)
    end

    # pp @checked_items
  end

  private

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

  # Checks one item against Fedora.
  def dispatch_item(fedora_id)
    response = fedora_connection.get('/fedora/rest/prod/' + fedora_id).body
    obj = Yajl::Parser.new.parse(response)[0]
    model = obj["info:fedora/fedora-system:def/model#hasModel"][0]["@value"]
    if ['FileSet', 'GenericWork'].include? model
      item = local_item(obj['@id'])
      if item.nil?
        puts "MISSING: #{model} in destination for #{obj['@id'].gsub(/^.*prod\//, '')}"
        return
      end
      if model == 'GenericWork'
        unless item.is_a? Work
          puts "MISMATCH: #{model} in source, #{item.type} in destination."
          return
        end
        FedoraItemChecker.new(
          fedora_data: obj, local_item:item,
          fedora_connection:fedora_connection,
          options:@options).check_generic_work

      elsif model == 'FileSet'
        unless item.is_a? Asset
          puts "MISMATCH: #{model} in source, #{item.type} in destination."
          return
        end
        FedoraItemChecker.new(
          fedora_data: obj, local_item:item,
          fedora_connection:fedora_connection,
          options:@options).check_file_set

      end
      unless item.nil?
        @checked_items[model] = [] unless @checked_items[model]
        @checked_items[model] << item.friendlier_id
      end
    end
  end
end