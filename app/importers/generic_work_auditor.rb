class GenericWorkAuditor < Auditor
  def special_checks()
    confirm(@item.type == "Work", "is a work")
    check_child_info()
    check_array_attributes()
  end

  def check_physical_container()
    return if metadata['physical_container'].nil?
    map = {'b'=>'box', 'f'=>'folder', 'v'=>'volume',
      'p'=>'part', 'g'=>'page', 's'=>'shelfmark'}
    args = metadata['physical_container'].
      split('|').
      map{ |x| { map[x[0]] => x[1..-1] } }.
      inject(:merge)
    new_item.build_physical_container(args)
  end

  def check_creator()
    Work::Creator::CATEGORY_VALUES.each do |k|
      next if metadata[k].nil?
      metadata[k].each do |v|
        new_item.build_creator({'category'=>k, 'value'=>v})
      end
    end
  end

  def check_additional_credit()
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

  def check_date()
    return if metadata['dates'].nil?
    metadata['dates'].each do |d|
      new_item.build_date_of_work(d)
    end
  end

  def check_place()
    Work::Place::CATEGORY_VALUES.each do |k|
      next if metadata[k].nil?
      metadata[k].each do |v|
        new_item.build_place({'category'=>k, 'value'=>v})
      end
    end
  end

  def check_inscriptions()
    return if metadata['inscriptions'].nil?
    metadata['inscriptions'].each do |ins|
      params = {
          'location' => ins['location'],
          'text'     => ins['text']
      }
      new_item.build_inscription(params)
    end
  end

  def check_external_id()
    @metadata['identifier'].each do |x|
      category, value = x.split('-')
      @new_item.build_external_id({'category' => category, 'value' => value})
    end
  end

  def check_scalar_attributes()
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

  def check_array_attributes()
    mapping = {
      'genre_string' => 'genre'
    }
    %w(extent language genre_string subject additional_title exhibition series_arrangement related_url).each do |source_k|
      dest_k = mapping.fetch(source_k, source_k)
      if metadata[source_k].nil?
        confirm(@item.send(dest_k) == [], source_k)
      else
        confirm(@item.send(dest_k) == metadata[source_k], source_k)
      end
    end
    # format:
    confirm(metadata['resource_type'].first.downcase == item.format.first, 'resource type / format')

  end



  def check_child_info()

    return if metadata['child_ids'] == nil

    confirm(@item.members.pluck(:friendlier_id) == metadata['child_ids'], "members")

    the_id = @item.friendlier_id

    unless metadata['representative_id'].nil?
      confirm( @item.representative.friendlier_id == metadata['representative_id'], "representative")
    end

  end

  def self.importee()
    return 'GenericWork'
  end

  def self.destination_class()
    return Work
  end


end
