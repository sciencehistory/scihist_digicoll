module Importers
  class GenericWorkImporter < Importers::Importer
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


    def add_physical_container()
      return if metadata['physical_container'].nil?
      map = {'b'=>'box', 'f'=>'folder', 'v'=>'volume',
        'p'=>'part', 'g'=>'page', 's'=>'shelfmark'}
      args = metadata['physical_container'].
        split('|').
        map{ |x| { map[x[0]] => x[1..-1] } }.
        inject(:merge)
      target_item.build_physical_container(args)
    end

    def add_creator()
      target_item.creator = []
      Work::Creator::CATEGORY_VALUES.each do |k|
        next if metadata[k].nil?
        metadata[k].each do |v|
          target_item.build_creator({'category'=>k, 'value'=>v})
        end
      end
    end

    def add_additional_credit()
      target_item.additional_credit = []
      role_map = {'photographer' => 'photographed_by'}
      return if metadata['additional_credits'].nil?
      metadata['additional_credits'].each do |a_c|
        params = {
          'role' => role_map.fetch(a_c['role'], a_c['role']),
          'name' => a_c['name']
        }
        target_item.build_additional_credit(params)
      end
    end

    def add_date()
      target_item.date_of_work = []
      return if metadata['dates'].nil?

      metadata['dates'].each do |d|
        next if d.nil?
        d['start_qualifier'].downcase!  if d['start_qualifier']
        d['finish_qualifier'].downcase! if d['finish_qualifier']
        # Pad dates prior to 1000 CE with zeros:
        d['start' ] = d['start' ].rjust(4, padstr='0') if d['start' ]
        d['finish'] = d['finish'].rjust(4, padstr='0') if d['finish']
        target_item.build_date_of_work(d)
      end
    end

    def add_place()
      target_item.place = []
      Work::Place::CATEGORY_VALUES.each do |k|
        next if metadata[k].nil?
        metadata[k].each do |v|
          target_item.build_place({'category'=>k, 'value'=>v})
        end
      end
    end

    def add_inscriptions()
      target_item.inscription = []
      return if metadata['inscriptions'].nil?

      metadata['inscriptions'].each do |ins|
        params = {
            'location' => ins['location'],
            'text'     => ins['text']
        }
        target_item.build_inscription(params)
      end
    end

    def add_external_id()
      target_item.external_id = []
      @metadata['identifier'].each do |x|
        category, value = x.split('-')
        target_item.build_external_id({'category' => category, 'value' => value})
      end
    end

    def add_scalar_attributes()
      mapping = {
        'division' => 'department'
      }

      %w(description provenance provenance_notes format source rights rights_holder file_creator division admin_note).each do |k|
        next if @metadata[k].nil?
        v = metadata[k].class == String ? metadata[k] : metadata[k].first
        property_to_set = mapping.fetch(k, k)
        target_item.send("#{property_to_set}=", v)
      end
    end

    def add_resource_type
      # Convert the resource_type / format strings to slugs:
      target_item.format = (metadata['resource_type'] || []).map! {|x| x.downcase.gsub(' ', '_') }
    end

    def add_array_attributes()
      mapping = {
        'genre_string' => 'genre'
      }
      %w(extent medium language genre_string subject additional_title exhibition project series_arrangement related_url).each do |source_k|
        dest_k = mapping.fetch(source_k, source_k)
        if metadata[source_k].nil?
          target_item.send("#{dest_k }=", [])
        else
          target_item.send("#{dest_k }=", metadata[source_k])
        end
      end
    end
  end
end
