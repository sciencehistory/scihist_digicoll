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

    @unchecked_metadata = fedora_data.keys.sort

    @fedora_id = strip_prefix(fedora_data['@id'])
    @unchecked_metadata.delete ('@id')

    @model = item_val('has_model')
  end

  def check(target_class)
    if target_class == Work
      check_generic_work
    elsif target_class == Asset
      check_file_set
    elsif target_class == Collection
      check_collection
    else
      raise ArgumentError.new("Can't check for class #{target_class}")
    end

    if @unchecked_metadata.present?
      log """ERROR: #{@fedora_id} unchecked metadata. #{ pp @unchecked_metadata.sort }"""
    end

  end

  def check_collection()
    @collection = @local_item
    # title
    check_and_log( flag: "title",
      old_val: item_val('title'),
      new_val: @collection.title,
    )
    # description
    check_and_log( flag: 'description',
      old_val: all_item_vals('description').select { |d| d.present?}.first,
      new_val: @collection.description,
    )
    # see also
    check_and_log( flag: "related_url",
      old_val: all_item_vals("related_url"),
      new_val: @collection.related_url
    )
    # membership
    check_and_log( flag: "collection members",
      old_val: all_item_ids('http://pcdm.org/models#hasMember').map { |m| m.gsub(/.*\//, '') }.sort,
      new_val:  @collection.contains.pluck(:friendlier_id).sort
    )
    # Access control:
    check_access_control
  end


  def check_generic_work
    @work = @local_item

    check_work_scalar_attributes
    check_work_array_attributes
    check_work_external_id
    check_work_creator
    check_work_file_creator
    check_work_additional_credit
    check_work_date
    check_work_place
    check_work_inscription
    check_work_physical_container
    check_work_admin_note
    check_work_representative
    check_work_contents

    check_access_control
    check_created_at
    check_modified
  end

  def check_work_scalar_attributes()
    mapping = FedoraMappings.scalar_attributes
    %w(description division provenance rights rights_holder source title digitization_funder).each do |k|
      check_and_log( flag: k,
        old_val: item_val(k),
        new_val: @work.send(mapping.fetch(k, k).to_sym)
      )
    end
  end

  def check_work_admin_note()
    check_and_log( flag: "admin_note",
      old_val: all_item_vals('admin_note'),
      new_val: @work.admin_note.sort
    )
  end

  def check_work_array_attributes()
    mapping = FedoraMappings.array_attributes
    %w(extent medium language genre_string subject additional_title exhibition project series_arrangement related_url).each do |k|
      check_and_log( flag: k,
        old_val:  all_item_vals(k),
        new_val: @work.send(mapping.fetch(k, k).to_sym).sort
      )
    end
    # Format / Resource type
    check_and_log( flag: "Format",
      old_val:  all_item_vals('resource_type'),
      new_val: @work.format,
      compare_method: :compare_format,
      order_matters: false
    )
  end

  def compare_format(item)
     item.downcase.gsub(' ', '_')
  end

  def check_work_external_id()
    check_and_log( flag: "External id",
      old_val: all_item_vals("identifier"),
      new_val: @work.external_id.map {|id| id.attributes },
      compare_method: :compare_external_id,
      order_matters: false
    )
  end
  def compare_external_id(item)
    category, value = item.split('-')
    {'category' => category, 'value' => value }
  end

  def check_work_creator()
    Work::Creator::CATEGORY_VALUES.each do |k|
      check_and_log( flag: k,
        old_val: all_item_vals(k),
        new_val: @work.creator.select { |c| c.category == k }.map {|id| id.attributes['value'] },
        order_matters: false
      )
    end
  end

  def check_work_file_creator()
    check_and_log( flag: "file_creator",
      old_val: item_val('file_creator'),
      new_val: @work.file_creator
    )
  end

  def check_work_additional_credit()
    uri = FedoraMappings.work_reflections[:additional_credit][:uri]
    check_and_log( flag: "Additional credit",
      old_val: all_item_ids(uri),
      new_val: @work.additional_credit.map {|id| id.attributes }
      compare_method: :compare_additional_credit,
      order_matters:false
    )
  end
  def compare_additional_credit(item)
    ac_data = get_fedora_item(item)[0]
    name = ac_data['http://xmlns.com/foaf/0.1/name'][0]['@value']
    role = ac_data['http://chemheritage.org/ns/hasCreditRole'][0]['@value']
    mapping = FedoraMappings.additional_credit_roles
    { "name" => name, "role" => mapping.fetch(role, role) }
  end

  def check_work_date()
    uri = FedoraMappings.work_reflections[:date_of_work][:uri]
    check_and_log( flag: "Date",
      old_val: all_item_ids(uri),
      new_val: @work.date_of_work.
        map {|dw|  dw.attributes }.
        map {|att| att.select { |k,v| v != ""} },
      compare_method: :compare_date,
      order_matters: false
    )
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

  def check_work_place()
    Work::Place::CATEGORY_VALUES.each do |place_category|
      check_and_log( flag: place_category,
        old_val: all_item_vals(place_category),
        new_val: @work.place.
          select {|p| p.attributes['category'] == place_category}.
          map { |c| c.attributes['value']}
      )
    end
  end

  def check_work_inscription()
    uri = FedoraMappings.work_reflections[:inscription][:uri]
    check_and_log( flag: "Inscription",
      old_val: all_item_ids(uri),
      new_val: @work.inscription.map { |i| i.attributes},
      compare_method: :compare_inscription,
      order_matters: false
    )
  end
  def compare_inscription(item)
    inscription_hash = get_fedora_item(item)[0]
    url_mapping = FedoraMappings.inscriptions
    Hash[ url_mapping.map { |k, v| [k.to_s,  get_val(inscription_hash, url_mapping[k]) ] } ]
  end


  def check_access_control()
    check_and_log( flag: "Published?",
      old_val: is_public,
      new_val: @local_item.published?,
    )
  end

  def is_public()
    uri = FedoraMappings.work_reflections[:access_control][:uri]
    access_control_id   = item_id(uri)
    return false unless access_control_id
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

  def check_work_contents()
    @unchecked_metadata.delete ('http://www.w3.org/ns/ldp#contains')
    new_val = @local_item.members.order(:position).pluck(:friendlier_id)
    old_val = contents_1.map { |x| x.gsub(/.*\//, '') }
    if old_val.count > 1 && old_val[0...-1] == new_val
      # Sufia bug: Fedora lists one extra item in contents_1.
      # This extra item is *not* listed in contents_2, and
      # does not show up in the Sufia front end.
      # Workaround:
      # Keep only get_contents_1 that are *also* in contents_2.
      old_val = old_val & contents_2
    end

    check_and_log( flag: "Contents",
      old_val: old_val,
      new_val: new_val
    )
  end

  # A list of members (either FileSets or child GenericWorks) in this GenericWork.
  # This is the correct order for the list of members, but it might contain extra items,
  # repetitions, or items that point to nothing.
  # Derived from #{@fedora_id}/members
  def contents_1()
    return [] unless @fedora_data.key? 'http://www.w3.org/ns/ldp#contains'
    # Fetch the unordered of member proxies:
    list_source =  get_fedora_item("#{@fedora_id}/list_source")

    if @fedora_id == '3r/07/4v/25/3r074v259'
      # Special case:
      # This private work has a tombstone resource (HTTP error 410)
      # at fedora/rest/prod/3r/07/4v/25/3r074v259/list_source.
      #
      # Nonetheless, the export and import process worked fine:
      # https://digital.sciencehistory.org/works/3r074v259
      # https://digital.sciencehistory.org/concern/parent/3r074v259/file_sets/xw42n8192
      # https://kithe.sciencehistory.org/admin/works/3r074v259
      # https://kithe.sciencehistory.org/admin/asset_files/xw42n8192
      # There's no point in writing code for this one case:
      # the file is private, and if we don't want it around,
      # we can delete it in either Sufia or in Kithe.
      return ["xw42n8192"]
    end

    return [] unless list_source
    return [] unless list_source[0].key? 'http://www.iana.org/assignments/relation/first'
    @unchecked_metadata.delete ('http://www.iana.org/assignments/relation/first')

    # Organize the member proxies into a linked list:
    linked_list = {}
    list_source.each do |l_i|
      linked_list[l_i["@id"]] = {member:look_up_proxy(l_i), next:next_item(l_i)}
    end
    #Try to look up each member in the linked list of member proxies.
    ordered_items = []
    proxy_id = list_source[0]['http://www.iana.org/assignments/relation/first'][0]["@id"]
    while proxy_id
      current = linked_list[proxy_id]
      if current[:member] && !(ordered_items.include? current[:member])
        ordered_items << current[:member]
      end
      proxy_id = current[:next]
    end
    ordered_items
  end

  # A list of members (either FileSets or child GenericWorks) in this GenericWork.
  # This is the correct list of members, but in an arbitrary order.
  # Derived from #{@fedora_id}/list_source
  def contents_2()
    members_list = get_fedora_item("#{@fedora_id}/members")&.first
    get_all_ids(members_list, 'http://www.w3.org/ns/ldp#contains').map do |tmp|
      get_id(get_fedora_item(tmp)[0], "http://www.openarchives.org/ore/terms/proxyFor")&.gsub(/.*\//, '')
    end
  end


  # The actual Fedora item for which this list item is a proxy, if any.
  def look_up_proxy(list_item)
    list_item.dig("http://www.openarchives.org/ore/terms/proxyFor", 0, "@id")
  end

  # The next list item, if any.
  def next_item(list_item)
    list_item.dig("http://www.iana.org/assignments/relation/next",  0, "@id")
  end

  def check_work_physical_container()
    check_and_log( flag: "Physical Container",
      old_val: compare_physical_container(item_val('physical_container')),
      new_val: @work&.physical_container&.attributes&.reject {|k, v| v == ""}
    )
  end
  def compare_physical_container(item)
    return nil if item.nil?
    p_c_map = FedoraMappings.physical_container
    match_this = item.
      split('|').
      map{ |x| { p_c_map[x[0]] => x[1..-1] } }.
      inject(:merge)
  end

  def check_work_representative()
    uri = FedoraMappings.work_reflections[:representative][:uri]
    check_and_log( flag: "Representative",
      old_val: item_id(uri)&.gsub(/^.*\//, ''),
      new_val: @work&.representative&.friendlier_id
    )
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
    if file_metadata.nil?
      log("WARNING: No file attached to FileSet #{@fedora_id}. Will not check title, filename or sha1.")
      return
    end
    check_file_set_title
    check_file_set_filename
    check_file_set_integrity
    check_access_control
    check_created_at
    check_modified
  end

  def check_file_set_filename()
    check_and_log( flag: "Original filename",
      old_val: get_val(file_metadata,'http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#filename'),
      new_val: @asset&.file&.metadata.try { |h| h["filename"]}
    )
  end

  def check_file_set_title()
    orig_filename = @asset&.title
    return if orig_filename.nil?
    check_and_log(
      flag: 'title',
      old_val: item_val('title'),
      new_val: orig_filename,
    )
  end

  def check_created_at()
    check_and_log(
      flag: 'created_at',
      old_val: one_second_precision(item_val('date_uploaded')),
      new_val: @local_item.created_at.utc
    )
  end

  def check_modified()
    check_and_log(
      flag: 'created_at',
      old_val: one_second_precision(item_val("date_modified")),
      new_val: @local_item.updated_at.utc
    )
  end

  def one_second_precision(date_string)
    str = date_string.
      gsub(/(T\d\d:\d\d:\d\d)\.\d*/, '\1')
    DateTime.parse(str).utc
  end

  def check_file_set_integrity()
    # A nil file would be reported in the
    # fixity check report, so we are
    # passing over this case.
    return if @asset.file.nil?

    # Check the file is actually in s3:
    unless @asset.file.exists?
      log("ERROR: File is missing in s3 for #{@asset.friendlier_id}")
      return
    end

    # Check its sha1 against Fedora:
    check_and_log(
      flag: "sha1",
      old_val: file_sha1,
      new_val: @asset.sha1
    )
  end

  def file_metadata
    @file_metadata ||= begin
      file_download_id = item_id('http://pcdm.org/models#hasFile')
      return nil if file_download_id.nil?
      get_fedora_item("#{file_download_id}/fcr:metadata")[0]
    end
  end

  def file_sha1
    @file_sha1 ||= get_id(file_metadata, 'http://www.loc.gov/premis/rdf/v1#hasMessageDigest')&.gsub(/^.*:/, '')
  end


  private

  #Get one metadata value from @fedora_data
  def item_val(key)
    uri = FedoraMappings.properties[key]
    @unchecked_metadata.delete(uri)
    get_val(@fedora_data, uri)
  end

  #Get an array of values from @fedora_data
  def all_item_vals(key)
    uri = FedoraMappings.properties[key]
    @unchecked_metadata.delete(uri)
    get_all_vals(@fedora_data, uri)
  end

  # Get an array of URIs from @fedora_data
  def all_item_ids(key)
    @unchecked_metadata.delete(key)
    get_all_ids(@fedora_data, key)
  end

  # Get a single URI from @fedora_data
  def item_id(key)
    @unchecked_metadata.delete(key)
    get_id(@fedora_data, key)
  end

  # Extract one or more metadata values from a Fedora properties hash:
  def get_val(obj, key)
    obj[key][0]["@value"] unless obj[key].nil?
  end
  def get_all_vals(obj, key)
    return [] if  obj[key].nil?
    obj[key].map { |v| v['@value'] }.sort
  end

  # Get one or several URLs from a Fedora properties hash:
  def get_id(obj, key)
    get_all_ids(obj, key)&.first
  end

  def get_all_ids(obj, key)
    return [] if  obj[key].nil?
    obj[key].map { |v| strip_prefix(v["@id"]) }
  end

  def get_fedora_item(id_str)
    response = @fedora_connection.get('/fedora/rest/prod/' + id_str)
    return nil if [410, 404].include?(response.status)
    JSON.parse(response.body)
  end

  def strip_prefix(str)
    str.gsub(/^.*\/fedora\/rest\/prod\//, '')
  end

  def check_and_log(flag:, old_val:, new_val:, compare_method: nil, order_matters: true)
    if compare_method
      old_val = old_val.map { |el| send(compare_method, el) }
    end
    result = FedoraPropertyChecker.new(
      flag: flag,
      old_val: old_val,
      new_val: new_val,
      fedora_id: @fedora_id
    ).check()
    log(result) if result
  end

  def log(msg)
    @progress_bar ? @progress_bar.log(msg) : puts(msg)
  end
end