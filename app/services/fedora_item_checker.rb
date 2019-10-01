# Checks the data from a single item (e.g. a Work or an Asset) in Fedora against our database.
# May perform additional calls to Fedora as needed.
class FedoraItemChecker
  def initialize(fedora_data, local_item, fedora_connection, fedora_host_and_port)
    @fedora_data = fedora_data
    @local_item = local_item
    @fedora_connection = fedora_connection
    @model = get_val(fedora_data,"info:fedora/fedora-system:def/model#hasModel")
    @fedora_id = strip_prefix(fedora_data['@id'])
    @fedora_host_and_port = fedora_host_and_port
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
    check_inscriptions
    check_physical_container
  end

  def check_external_id()
    old_val = get_all_vals(@fedora_data, FedoraMappings.work_properties["identifier"])
    new_val = @work.external_id
    if (old_val.count == 0 || old_val.nil?) && @work.external_id.count > 0
      confirm(found, "Stray external ID", nil, work.external_id)
    end
    old_val.each do |x|
      category, value = x.split('-')
      params = {'category' => category, 'value' => value}
      found = (@work.external_id.detect { |id| id.attributes == params } )
      confirm(found, "No external ID", x, nil)
    end
  end

  def check_scalar_attributes()
    mapping = FedoraMappings.scalar_attributes
    %w(admin_note description division file_creator provenance rights rights_holder source digitization_funder).each do |k|
      old_val = get_val(@fedora_data, FedoraMappings.work_properties[k])
      work_property_to_check = mapping.fetch(k, k).to_sym
      new_val = @work.send(work_property_to_check)
      check_val(old_val, new_val, "Bad #{k}")
    end
  end

  def check_array_attributes()
    mapping = FedoraMappings.array_attributes
    %w(extent medium language genre_string subject additional_title exhibition project series_arrangement related_url).each do |source_k|
      work_property_to_check = mapping.fetch(source_k, source_k).to_sym
      old_val = get_all_vals(@fedora_data, FedoraMappings.work_properties[source_k])
      new_val = @work.send(work_property_to_check).sort
      check_arr(old_val, new_val, "Bad #{source_k}")
    end

    # Format / Resource type
    fedora_formats = get_all_vals(@fedora_data, FedoraMappings.work_properties['resource_type'])
    confirm(fedora_formats.collect{ |x| x.downcase.gsub(' ', '_')} == @work.format,
      "Bad formats", fedora_formats, @work.format
    )
  end

  def check_creator()
    Work::Creator::CATEGORY_VALUES.each do |k|
      fedora_vals = get_all_vals(@fedora_data, FedoraMappings.work_properties[k])
      matches = @work.creator.select { |c| c.category == k } || []
      confirm(fedora_vals.count ==  matches.count, "wrong number of #{k}")
      fedora_vals.each do |val|
        found = (@work.creator.detect { |c| c.category == k && c.value == val } )
        confirm(found, k, val, found)
      end
    end
  end

  def check_additional_credit()
    fedora_vals = get_all_vals(@fedora_data, FedoraMappings.work_properties['additional_credits'])
    confirm(fedora_vals.count ==  @work.additional_credit.count, "wrong number of additional_credits")
    role_map = FedoraMappings.additional_credit_roles
    fedora_vals.each do |a_c|
      params = {
        'role' => role_map.fetch(a_c['role'], a_c['role']),
        'name' => a_c['name']
      }
      found = (@work.additional_credit.detect { |c| c.attributes == params } )
      confirm(found, 'additional_credit', a_c, nil)
    end
    confirm(@work.additional_credit.count == fedora_vals.count, 'additional credit count')
  end

  def check_date()
    date_uri = FedoraMappings.work_reflections[:date_of_work][:uri]
    fedora_vals =  get_all_ids(@fedora_data, date_uri)
    confirm(fedora_vals.count ==  @work.date_of_work.count, "wrong number of dates")
    fedora_vals.each do |url|
      date_hash = parse(get_fedora_item(url))[0]
      url_mapping = FedoraMappings.dates
      match_this = Hash[ url_mapping.map { |k, v| [k.to_s,  get_val(date_hash, url_mapping[k]) ] } ]
      match_this.delete_if {|key, value| value == "" }
      match_this['start_qualifier'].downcase!  if match_this['start_qualifier']
      match_this['finish_qualifier'].downcase! if match_this['finish_qualifier']
      match_this['start' ] = match_this['start' ].rjust(4, padstr='0') if match_this['start' ]
      match_this['finish'] = match_this['finish'].rjust(4, padstr='0') if match_this['finish']
      found = (@work.date_of_work.detect { |wd| wd.attributes == match_this } )
      confirm(found, 'date', match_this, nil)
    end
  end

  def check_place()
    Work::Place::CATEGORY_VALUES.each do |k|
      fedora_vals = get_all_vals(@fedora_data, FedoraMappings.work_properties[k])
      confirm(fedora_vals.count == @work.place.count{|p| p.attributes['category'] == k}, "wrong number of #{k}")
      fedora_vals.each do |v|
        found = (@work.place.detect { |p| p.attributes == {'category'=>k, 'value'=>v} } )
        confirm(found, 'place')
      end
    end
  end

  def check_inscriptions()
    date_uri = FedoraMappings.work_reflections[:inscription][:uri]
    fedora_vals =  get_all_ids(@fedora_data, date_uri)
    confirm(@work.inscription.count == fedora_vals.count, 'inscrption_count', fedora_vals, @work.inscription)
    fedora_vals.each do |url|
      inscription_hash = parse(get_fedora_item(url))[0]
      url_mapping = FedoraMappings.inscriptions
      tmp = Hash[ url_mapping.map { |k, v| [k.to_s,  get_val(inscription_hash, url_mapping[k]) ] } ]
      found = (@work.inscription.detect { |p| p.attributes == tmp } )
      confirm(found, 'inscription', tmp, @work.inscription)
    end
  end

  def check_physical_container()
    old_val = get_val(@fedora_data, FedoraMappings.work_properties['physical_container'])
    unless old_val.present?
      confirm(@work.physical_container.nil?, 'stray physical_container', nil, @work.physical_container)
      return
    end
    non_blank_fields = @work.physical_container.attributes.reject {|k, v| v == ""}
    map = FedoraMappings.physical_container
    match_this = old_val.
      split('|').
      map{ |x| { map[x[0]] => x[1..-1] } }.
      inject(:merge)
    confirm(non_blank_fields == match_this, 'physical_container')
  end


  def check_file_set()
    # Todo: file checksum (available in file_sha1)
    # Todo: access control
    asset = @local_item
    id = get_val(@fedora_data, '@id')
    orig_filename = asset&.file&.metadata.try { |h| h["filename"]}

    unless orig_filename.nil?
      check_val(get_val(@fedora_data,'info:fedora/fedora-system:def/model#downloadFilename'), orig_filename, "Bad orig. filename")
    end
    date_submitted = get_val(@fedora_data,'http://purl.org/dc/terms/dateSubmitted').gsub(/\.\d*\+/, '+')
    check_val(DateTime.parse(date_submitted).utc, asset.created_at.utc, "Bad date")
  end

  def file_metadata
    @file_metadata ||= begin
      file_download_id = get_all_ids(@fedora_data, 'http://pcdm.org/models#hasFile').first
      file_metadata_path = "#{file_download_id}/fcr:metadata"
      parse(get_fedora_item(file_metadata_path))[0]
    end
  end

  def file_sha1
    @file_metadata ||= get_all_ids(file_metadata, 'http://www.loc.gov/premis/rdf/v1#hasMessageDigest').
    first.gsub(/^.*:/, '')
  end


  # Helper methods. These can be cleaned up a fair amount.
  def check_val(old_val, new_val, message)
    pass = (new_val == old_val) ||
      (new_val == '' and old_val.nil?) ||
      (old_val == '' and new_val.nil?)
    confirm(pass, message, old_val, new_val)
    return pass
  end

  def check_arr(old_val, new_val, message)
    pass = (new_val == old_val) || (new_val == [] and old_val.nil?)
    confirm(pass, message, old_val, new_val )
    return pass
  end

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
    "#{@fedora_host_and_port}/fedora/rest/prod/#{end_str}"
  end

  private

  def parse(s)
    Yajl::Parser.new.parse(s)
  end

  def get_fedora_item(id_str)
    response = @fedora_connection.get('/fedora/rest/prod/' + id_str)
    response.body
  end

  def strip_prefix(str)
    str.gsub(/^.*\/fedora\/rest\/prod\//, '')
  end

  def confirm(condition, report_string, old_value=nil, new_value=nil)
    report_line(report_string, old_value, new_value) unless condition
  end

  def report_line(str, old_value, new_value)
    prefix = if @local_item
      "#{@local_item.type} #{@local_item.friendlier_id} [#{@fedora_id}]"
    else
      "#{@model} #{fedora_id}"
    end
    puts("#{prefix}: #{str}. Fedora: #{old_value}. Scihist: #{new_value}")
  end
end