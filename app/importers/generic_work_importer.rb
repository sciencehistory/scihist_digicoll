class GenericWorkImporter < Importer

  # { parent_fid => [ child_fid, child_fid, child_fid], [...] }
  @@parent_to_child_hash ||= {}
  @@representative_hash  ||= {}
  @@thumbnail_hash       ||= {}

  def self.importee()
    return 'GenericWork'
  end

  def self.destination_class()
    return Work
  end

  def edit_metadata()
    @metadata['resource_type'].map! {|x| x.downcase.gsub(' ', '_') }
  end

  def populate()
    super
    empty_arrays()
    add_external_id()
    add_scalar_attributes()
    add_array_attributes()
    add_creator()
    add_additional_credit()
    add_date()
    add_place()
    add_inscriptions()
    add_physical_container()
  end

  def empty_arrays()
      new_item.date_of_work = []
      new_item.place = []
      new_item.creator = []
      new_item.exhibition = []
      new_item.additional_credit = []
      new_item.inscription = []
  end

  def add_physical_container()
    return if metadata['physical_container'].nil?
    map = {'b'=>'box', 'f'=>'folder', 'v'=>'volume',
      'p'=>'part', 'g'=>'page', 's'=>'shelfmark'}
    args = metadata['physical_container'].
      split('|').
      map{ |x| { map[x[0]] => x[1..-1] } }.
      inject(:merge)
    new_item.build_physical_container(args)
  end

  def add_creator()
    Work::Creator::CATEGORY_VALUES.each do |k|
      next if metadata[k].nil?
      metadata[k].each do |v|
        new_item.build_creator({'category'=>k, 'value'=>v})
      end
    end
  end

  def add_additional_credit()
    role_map = {'photographer' => 'photographed_by'}
    return if metadata['additional_credits'].nil?
    metadata['additional_credits'].each do |a_c|
      params = {
        'role' => role_map.fetch(a_c['role'], a_c['role']),
        'name' => a_c['name']
      }
      new_item.build_additional_credit(params)
    end
  end

  def add_date()
    return if metadata['dates'].nil?
    metadata['dates'].each do |d|
      new_item.build_date_of_work(d)
    end
  end

  def add_place()
    Work::Place::CATEGORY_VALUES.each do |k|
      next if metadata[k].nil?
      metadata[k].each do |v|
        new_item.build_place({'category'=>k, 'value'=>v})
      end
    end
  end

  def add_inscriptions()
    return if metadata['inscriptions'].nil?
    metadata['inscriptions'].each do |ins|
      params = {
          'location' => ins['location'],
          'text'     => ins['text']
        }
      new_item.build_inscription(params)
    end
  end

  def post_processing()
    store_parent_info()
  end

  def store_parent_info()
    # this info is processed later on in the import.
    return if metadata['child_ids'] == nil
    the_id = @new_item.friendlier_id
    @@parent_to_child_hash[the_id] = metadata['child_ids']

    unless metadata['representative_id'].nil?
      @@representative_hash[the_id] = metadata['representative_id']
    end

    unless metadata['thumbnail_id'].nil?
      @@thumbnail_hash[the_id] = metadata['thumbnail_id']
    end
  end

  def self.class_post_processing()
    self.link_children_and_parents()
  end

  # By the time this class method is called, ALL assets and works have been saved
  # to the DB and have their UUIDs ready.
  def self.link_children_and_parents()
    @@parent_to_child_hash.each_pair.each do | parent_id, child_ids |
      parent = Work.find_by_friendlier_id(parent_id)
      current_position = 0
      rep_fid = @@representative_hash[parent.friendlier_id]
      child_ids.each do |child_id|
        # This child could be a Work *or* an Asset.
        child = Kithe::Model.find_by_friendlier_id(child_id)
        if child.nil?
          raise StandardError,  "Unable to find child item #{child_id} for parent #{parent_id}"
        end
        child.parent_id = parent.id
        child.position = (current_position += 1)
        child.save!
        if child.friendlier_id == rep_fid
          parent.representative_id = child.id
          parent.save!
        end
      end # each child id
    end # each parent
  end # method


  def add_external_id()
    @metadata['identifier'].each do |x|
      category, value = x.split('-')
      @new_item.build_external_id({'category' => category, 'value' => value})
    end
  end

  def add_scalar_attributes()
    mapping = {
      'division' => 'department'
    }

    %w(description format source rights rights_holder file_creator division admin_note).each do |k|
      next if @metadata[k].nil?
      v = metadata[k].class == String ? metadata[k] : metadata[k].first
      property_to_set = mapping.fetch(k, k)
      @new_item.send("#{property_to_set}=", v)
    end
  end


  def add_array_attributes()
    mapping = {
      'resource_type' => 'format',
      'genre_string' => 'genre'
    }
    %w(resource_type extent language genre_string subject additional_title exhibition series_arrangement related_url).each do |source_k|
      dest_k = mapping.fetch(source_k, source_k)
      if metadata[source_k].nil?
        @new_item.send("#{dest_k }=", [])
      else
        @new_item.send("#{dest_k }=", metadata[source_k])
      end
    end
  end

  def how_long_to_sleep()
    3
  end

end
