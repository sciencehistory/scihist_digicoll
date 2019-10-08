require "byebug"
# Checks the data from a single item (e.g. a Work or an Asset) in Fedora against our database.
# May perform additional calls to Fedora as needed.
class FedoraItemChecker
  def initialize(fedora_data:, local_item:, fedora_connection:, progress_bar:, options:)
    @fedora_data = fedora_data
    @local_item = local_item
    @fedora_connection = fedora_connection
    @progress_bar =  progress_bar
    @options = options

    @fedora_id = strip_prefix(fedora_data['@id'])
    @model = get_val(fedora_data,"info:fedora/fedora-system:def/model#hasModel")
  end

  def check(target_class)
    if target_class == Work
      check_generic_work
    elsif target_class == Asset
      check_file_set
    else
      raise ArgumentError.new("Can't check for class #{target_class}")
    end
  end

  def check_generic_work
    @work = @local_item
    check_scalar_attributes
    check_array_attributes
    check_external_id
    check_creator
    check_additional_credit
    check_date
    check_place
    check_inscription
    check_physical_container
    check_admin_note
    check_representative
    check_access_control
  end

  def check_scalar_attributes()
    mapping = FedoraMappings.scalar_attributes
    %w(description division file_creator provenance rights rights_holder source digitization_funder).each do |k|
      old_val = get_val(@fedora_data, FedoraMappings.work_properties[k])
      work_property_to_check = mapping.fetch(k, k).to_sym
      new_val = @work.send(work_property_to_check)
      confirm(compare(old_val, new_val), "#{k}", old_val, new_val)
    end
  end

  def check_admin_note()
    # Not implemented yet.
  end

  def check_array_attributes()
    mapping = FedoraMappings.array_attributes
    %w(extent medium language genre_string subject additional_title exhibition project series_arrangement related_url).each do |source_k|
      work_property_to_check = mapping.fetch(source_k, source_k).to_sym
      old_val = get_all_vals(@fedora_data, FedoraMappings.work_properties[source_k])
      new_val = @work.send(work_property_to_check).sort
      confirm(compare(old_val, new_val), "#{source_k}", old_val, new_val)
    end

    # Format / Resource type
    old_val = get_all_vals(@fedora_data, FedoraMappings.
      work_properties['resource_type'])
    new_val = @work.format
    correct = compare(old_val, new_val, :compare_format, order_matters:false)
    confirm(correct, "Format", old_val, new_val)
  end

  def compare_format(item)
     item.downcase.gsub(' ', '_')
  end

  def check_external_id()
    old_val = get_all_vals(@fedora_data, FedoraMappings.work_properties["identifier"])
    new_val = @work.external_id.map {|id| id.attributes }
    correct = compare(old_val, new_val, :compare_external_id, order_matters:false)
    confirm(correct, "External id", old_val, new_val)
  end
  def compare_external_id(item)
    category, value = item.split('-')
    {'category' => category, 'value' => value }
  end


  def check_creator()
    Work::Creator::CATEGORY_VALUES.each do |k|
      old_val = get_all_vals(@fedora_data, FedoraMappings.work_properties[k])
      new_val = @work.creator.
        select { |c| c.category == k }.
        map {|id| id.attributes['value'] }
      confirm(compare(old_val, new_val, order_matters: false), "#{k}", old_val, new_val)
    end
  end


  def check_additional_credit()
    uri = FedoraMappings.work_reflections[:additional_credit][:uri]
    old_val = get_all_ids(@fedora_data, uri)
    new_val = @work.additional_credit.map {|id| id.attributes }
    correct = compare(old_val, new_val, :compare_additional_credit, order_matters:false )
    confirm(correct, "Additional credit", old_val.map {|x| compare_additional_credit(x)}, new_val)
  end
  def compare_additional_credit(item)
    ac_data = get_fedora_item(item)[0]
    name = ac_data['http://xmlns.com/foaf/0.1/name'][0]['@value']
    role = ac_data['http://chemheritage.org/ns/hasCreditRole'][0]['@value']
    mapping = FedoraMappings.additional_credit_roles
    { "name" => name, "role" => mapping.fetch(role, role) }
  end


  def check_date()
    uri = FedoraMappings.work_reflections[:date_of_work][:uri]
    old_val = get_all_ids(@fedora_data, uri)
    new_val = @work.date_of_work.
      map {|dw|  dw.attributes }.
      map {|att| att.select { |k,v| v != ""} }
    correct = compare(old_val, new_val, :compare_date, order_matters: false)
    confirm(correct, "Date", old_val.map {|x| compare_date(x)}, new_val)
  end

  def compare_date(item)
    date_hash = get_fedora_item(item)[0]
    url_mapping = FedoraMappings.dates
    result = Hash[ url_mapping.map { |k, v| [k.to_s,  get_val(date_hash, url_mapping[k]) ] } ]
    result.delete_if {|key, value| value == "" }
    result['start_qualifier'].downcase!  if result['start_qualifier']
    result['finish_qualifier'].downcase! if result['finish_qualifier']
    result['start' ] = result['start' ].rjust(4, padstr='0') if result['start' ]
    result['finish'] = result['finish'].rjust(4, padstr='0') if result['finish']
    result
  end

  def check_place()
    Work::Place::CATEGORY_VALUES.each do |place_category|
      old_val = get_all_vals(@fedora_data, FedoraMappings.work_properties[place_category])
      new_val = @work.place.
        select {|p| p.attributes['category'] == place_category}.
        map { |c| c.attributes['value']}
      correct = compare(old_val, old_val)
      confirm(correct, place_category, old_val, new_val)
    end
  end

  def check_inscription()
    uri = FedoraMappings.work_reflections[:inscription][:uri]
    old_val =  get_all_ids(@fedora_data, uri)
    new_val = @work.inscription.map { |i| i.attributes}
    correct = compare(old_val, new_val, :compare_inscription, order_matters:false)
    confirm(correct, "Inscription", old_val.map {|x| compare_inscription(x)}, new_val)
  end
  def compare_inscription(item)
    inscription_hash = get_fedora_item(item)[0]
    url_mapping = FedoraMappings.inscriptions
    Hash[ url_mapping.map { |k, v| [k.to_s,  get_val(inscription_hash, url_mapping[k]) ] } ]
  end


  def check_access_control()
    old_val = is_public
    new_val = @local_item.published?
    correct = compare(old_val, new_val)
    confirm(correct, "Published?", old_val, new_val)
  end

  def is_public()
    uri = FedoraMappings.work_reflections[:access_control][:uri]
    access_control_id   = get_all_ids(@fedora_data, uri)&.first
    access_control_info = get_fedora_item(access_control_id)[0]
    access_control_list = get_all_ids(access_control_info, 'http://www.w3.org/ns/ldp#contains')
    access_control_list.each do |a_c_id|
      return true if allows_public_access(get_fedora_item(a_c_id)[0])
    end
    false
  end

  def allows_public_access(a_c)
    who         = 'http://www.w3.org/ns/auth/acl#agent'
    what        = 'http://www.w3.org/ns/auth/acl#mode'
    the_public  = 'http://projecthydra.org/ns/auth/group#public'
    can_read    = 'http://www.w3.org/ns/auth/acl#Read'
    a_c[who][0]['@id'] == the_public && a_c[what][0]['@id'] == can_read
  end

  def check_physical_container()
    raw_fedora_value = get_val(@fedora_data, FedoraMappings.work_properties['physical_container'])
    old_val = compare_physical_container(raw_fedora_value)
    new_val = @work&.physical_container&.attributes&.reject {|k, v| v == ""}
    correct = compare(old_val, new_val)
    confirm(correct, "Physical Container", old_val, new_val)
  end
  def compare_physical_container(item)
    return nil if item.nil?
    p_c_map = FedoraMappings.physical_container
    match_this = item.
      split('|').
      map{ |x| { p_c_map[x[0]] => x[1..-1] } }.
      inject(:merge)
  end

  def check_representative()
    uri = FedoraMappings.work_reflections[:representative][:uri]
    old_val = get_all_ids(@fedora_data, uri).map {| id| id.gsub(/^.*\//, '')}.first
    new_val = @work&.representative&.friendlier_id
    correct = compare(old_val, new_val)
    confirm(correct, "Representative", old_val, new_val)
  end

  #
  #
  #
  # FILE SETS:
  #
  #
  #

  def check_file_set()
    @asset = @local_item
    check_file_set_filename
    check_file_set_title
    check_file_set_created_at
    check_file_set_integrity
    check_access_control
  end

  def check_file_set_filename()
    new_val = @asset&.file&.metadata.try { |h| h["filename"]}
    old_val = get_val(file_metadata,'http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#filename')
    correct = compare(old_val, new_val)
    confirm(correct, "Original filename", old_val, new_val)
  end

  def check_file_set_title()
    orig_filename = @asset&.title
    unless orig_filename.nil?
      old_val = get_val(@fedora_data, FedoraMappings.work_properties['title'])
      new_val = orig_filename
      correct = compare(old_val, new_val)
      confirm(correct, "title", old_val, new_val)
    end
  end

  def check_file_set_created_at()
    old_val_str = get_val(@fedora_data,'http://purl.org/dc/terms/dateSubmitted').
      gsub(/\.\d*\+/, '+')
    old_val_date = (DateTime.parse(old_val_str)).utc
    new_val_date = @asset.created_at.utc
    correct = compare(old_val_date, new_val_date)
    confirm(correct, "created_at", old_val_date, new_val_date)
  end

  def check_file_set_integrity()
    # A nil file would be reported in the
    # fixity check report, so we are
    # passing over this case.
    return if @asset.file.nil?

    # Check the file is actually in s3:
    unless @asset.file.exists?
      confirm(false, "Missing in s3", "", @asset.friendlier_id)
      return
    end

    # Check its sha1 against Fedora:
    old_val = file_sha1
    new_val = @asset.sha1
    correct = compare(old_val, new_val)
    confirm(correct, "sha1", old_val, new_val)
  end

  def file_metadata
    @file_metadata ||= begin
      file_download_id = get_all_ids(@fedora_data, 'http://pcdm.org/models#hasFile').first
      file_metadata_path = "#{file_download_id}/fcr:metadata"
      get_fedora_item(file_metadata_path)[0]
    end
  end

  def file_sha1
    @file_sha1 ||= get_all_ids(file_metadata, 'http://www.loc.gov/premis/rdf/v1#hasMessageDigest').
      first.gsub(/^.*:/, '')
  end

  #
  #
  #
  # Getting stuff out of Fedora json objects:
  #
  #
  #

  def get_val(obj, key)
    obj[key][0]["@value"] unless obj[key].nil?
  end

  def get_all_vals(obj, key)
    return [] if  obj[key].nil?
    obj[key].map { |v| v['@value'] }.sort
  end

  def get_all_ids(obj, key)
    return [] if  obj[key].nil?
    obj[key].map { |v| strip_prefix(v["@id"]) }
  end

  def add_prefix(end_str)
    "#{@options[:fedora_host_and_port]}/fedora/rest/prod/#{end_str}"
  end

  private

  def get_fedora_item(id_str)
    response = @fedora_connection.get('/fedora/rest/prod/' + id_str)
    Yajl::Parser.new.parse(response.body)
  end

  def strip_prefix(str)
    str.gsub(/^.*\/fedora\/rest\/prod\//, '')
  end

  def confirm(condition, str, old_value=nil, new_value=nil)
    return if condition

    prefix = if @local_item
      "#{@model} #{@local_item.friendlier_id} [#{@fedora_id}]"
    else
      "#{@model} [#{fedora_id}]"
    end

    msg = """ERROR: #{prefix} ===> #{str}
        Fedora:
          #{old_value}
        Scihist:
          #{new_value}"""

    @progress_bar ? @progress_bar.log(msg) : puts(msg)
  end

  # Tests for equivalency between a and b.
  # Nil-tolerant, as it uses present? to determine
  # whether something exists.
  # Handles both scalars and arrays.
  # In the case of arrays,
  # pass in a mapping method if you want,
  # and it will be applied to a before comparing.
  def compare(a, b, the_method=nil, order_matters:true)

    # In source, not destination:
    return false if (!a.present? &&  b.present?)
    # In destination, not source:
    return false if (!b.present? &&  a.present?)
    # Absent in both:
    return true  if (!a.present? && !b.present?)

    # Scalar values:
    unless a.is_a? Array and b.is_a? Array
      return (a == b)
    end

    # If a mapping method provided,
    # map the values before comparing:
    mapped_values = if the_method.nil?
      a
    else
      a.map { |el| method(the_method).call(el) }
    end

    # Compare as an array if order matters:
    return mapped_values == b if order_matters

    # Compare as a set otherwise:
    mapped_values.to_set == b.to_set
  end



end