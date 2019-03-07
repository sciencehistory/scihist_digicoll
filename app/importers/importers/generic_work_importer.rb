module Importers
class Importers::GenericWorkImporter < Importers::Importer

  def self.importee()
    return 'GenericWork'
  end

  def self.destination_class()
    return Work
  end

  def corrected_resource_type
     (@metadata['resource_type'] || []).map! {|x| x.downcase.gsub(' ', '_') }
  end

  def populate()
    super
    empty_arrays()
    add_external_id()
    add_scalar_attributes()
    add_array_attributes()
    add_resource_type()
    add_creator()
    add_additional_credit()
    add_date()
    add_place()
    add_inscriptions()
    add_physical_container()
  end

  # This may no longer be needed, but having these be nil rather than
  # empty arrays wasn't handled well by one of the front-end templates.
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

    # unless @metadata['dates'].nil?
    #   @metadata['dates'].each { |x| x['start_qualifier'].downcase!  unless ( x.nil? || x['start_qualifier'].nil?)}
    #   @metadata['dates'].each { |x| x['finish_qualifier'].downcase! unless ( x.nil? || x['finish_qualifier'].nil?) }
    # end


    return if metadata['dates'].nil?
    metadata['dates'].each do |d|
      next if d.nil?
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
      if ins['text'].nil?
        add_error("ERROR: bad inscription: location, but no text.")
        next
      end
      params = {
          'location' => ins['location'],
          'text'     => ins['text']
      }
      new_item.build_inscription(params)
    end
  end

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

  def add_resource_type
    # Convert the resource_type / format strings to slugs:
    @new_item.format = (metadata['resource_type'] || []).map! {|x| x.downcase.gsub(' ', '_') }
  end

  def add_array_attributes()
    mapping = {
      'genre_string' => 'genre'
    }
    %w(extent language genre_string subject additional_title exhibition series_arrangement related_url).each do |source_k|
      dest_k = mapping.fetch(source_k, source_k)
      if metadata[source_k].nil?
        @new_item.send("#{dest_k }=", [])
      else
        @new_item.send("#{dest_k }=", metadata[source_k])
      end
    end
  end
end
end
