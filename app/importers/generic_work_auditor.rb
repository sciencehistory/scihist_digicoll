# module Importers
class GenericWorkAuditor < Auditor
  def special_checks()
    confirm(@item.type == "Work", "is a work")
    check_child_info()
    check_scalar_attributes
    check_array_attributes
    check_physical_container
    check_creator
    check_additional_credit
    check_date
    check_inscriptions
    check_external_id
  end

  def check_physical_container()
    if metadata['physical_container'].nil? || metadata['physical_container'] == ""
      confirm(@item.physical_container.nil?, 'stray physical_container')
      return
    end
    if @item.physical_container.nil? 
      report_line("Missing phyical_container.")
      return
    end
    map = {'b'=>'box', 'f'=>'folder', 'v'=>'volume',
      'p'=>'part', 'g'=>'page', 's'=>'shelfmark'}
    args = metadata['physical_container'].
      split('|').
      map{ |x| { map[x[0]] => x[1..-1] } }.
      inject(:merge)
    confirm(@item.physical_container.attributes == args, 'physical_container')
  end

  def check_creator()
    Work::Creator::CATEGORY_VALUES.each do |k|
      if metadata[k].nil?
          found = (@item.creator.detect { |c| c.category == k } )
          confirm(!found, k)
      else
        metadata[k].each do |val|
          found = (@item.creator.detect { |c| c.category == k && c.value  ==  val } )
          confirm(found, k)
        end
      end
    end
  end

  def check_additional_credit()
    if metadata['additional_credits'].nil?
      confirm(@item.additional_credit == [], 'stray additional credits')
      return
    end
    role_map = {'photographer' => 'photographed_by'}
    metadata['additional_credits'].each do |a_c|
      params = {
        'role' => role_map.fetch(a_c['role'], a_c['role']),
        'name' => a_c['name']
      }
      found = (@item.additional_credit.detect { |c| c.attributes == params } )
      confirm(found, 'additional_credit')
      confirm(@item.additional_credit.count == metadata['additional_credits'].count, 'additional credit count')
    end
  end

  def check_date()
    if metadata['dates'].nil?
      confirm(@item.date_of_work.count == 0, 'stray date')
      return
    end
    unless @item.date_of_work.count == metadata['dates'].count
      report_line('date count')
      return
    end
    metadata['dates'].each do |d|
      d['start_qualifier'].downcase!  unless d['start_qualifier'].nil?
      d['finish_qualifier'].downcase! unless d['finish_qualifier'].nil?
      found = (@item.date_of_work.detect { |wd| wd.attributes == d } )
      byebug unless @item.date_of_work.detect { |wd| wd.attributes == d }
      confirm(found, 'date')
    end
  end

  def check_place()
    Work::Place::CATEGORY_VALUES.each do |k|
      if metadata[k].nil?
          found = (@item.place.detect { |p| p.attributes == {'category'=>k} } )
          confirm(!found, "stray place: #{k}")
      else
        metadata[k].each do |v|
          found = (@item.place.detect { |p| p.attributes == {'category'=>k, 'value'=>v} } )
          confirm(found, 'place')
        end
      end
    end
  end

  def check_inscriptions()
    if metadata['inscriptions'].nil?
      confirm(@item.inscription.count == 0, 'stray inscriptions')
      return
    end
    metadata['inscriptions'].each do |ins|
      params = {
          'location' => ins['location'],
          'text'     => ins['text']
      }
      found = (@item.inscription.detect { |p| p.attributes == params } )
      confirm(found, 'inscription')
    end
  end

  def check_external_id()
    if metadata['identifier'].nil?
      confirm(@item.external_id.count == 0, 'stray external_id')
      return
    end
    @metadata['identifier'].each do |x|
      category, value = x.split('-')
      params = {'category' => category, 'value' => value}
      found = (@item.external_id.detect { |id| id.attributes == params } )
      confirm(found, 'params')
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
      confirm(@item.send(property_to_set) == v, property_to_set)
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
    unless metadata['resource_type'].nil?
      confirm(metadata['resource_type'].collect{ |x| x.downcase.gsub(' ', '_')} == item.format, 'resource type / format')
    end
  end

  def check_child_info()
    if metadata['child_ids'].nil?
      confirm(@item.members.count == 0, "stray members")
      return
    end
    confirm(@item.members.order(:position).pluck(:friendlier_id) == metadata['child_ids'], "members")
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
# end
