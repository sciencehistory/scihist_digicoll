namespace :scihist do
  namespace :oh_microsite_import do
    require 'scihist_digicoll/oh_microsite_import_utilities/oh_microsite_import_utilities'
    require 'scihist_digicoll/oh_microsite_import_utilities/field_processor'
    require 'scihist_digicoll/oh_microsite_import_utilities/updaters'
    require 'scihist_digicoll/oh_microsite_import_utilities/interview_mapper'

    desc """
      bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata
      # Update only a specific set of digital collections works, based on their friendlier_id:
      bundle exec rake scihist:oh_microsite_import:import_interviewee_biographical_metadata[friendlier_id1,friendlier_id2,...]
    """
    task :import_interviewee_biographical_metadata => :environment do |t, args|

      if args.to_a.present?
        works = Kithe::Work.where(friendlier_id: args.to_a)
      else
        works = Kithe::Work.where("json_attributes -> 'genre' ?  'Oral histories'")
      end
      names = JSON.parse(File.read("#{files_location}/name.json"))
      unless names.is_a? Array
        puts "Error parsing names data."
        abort
      end
      mapper = InterviewMapper.new(names, works)
      mapper.construct_map()
      mapper.report()
      validation_errors = []

      metadata_files = %w{ birth_date birth_city birth_state birth_province birth_country } +
              %w{ death_date death_city death_state death_province death_country } +
              %w{ education career honors image interviewer}
      works_updated = Set.new()
      metadata_files.each do |field|
        rows = JSON.parse(File.read("#{files_location}/#{field}.json"))
        processor = FieldProcessor.new(field:field, works: works, mapper:mapper, rows: rows)
        processor.process()
        validation_errors += processor.errors()
        works_updated     += processor.works_updated()
      end
      if validation_errors.present?
        puts "#{validation_errors.join("\n")}"
      else
        puts "No validation errors."
      end
      puts "Works updated: #{works_updated.count}"
    end
  end
end