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
      works = works_we_want(args)
      mapper = InterviewMapper.new(works)
      mapper.construct_map
      mapper.report
      works_updated = Set.new; errors = []
      metadata_files.each do |field|
        rows = JSON.parse(File.read("#{files_location}/#{field}.json"))
        processor = FieldProcessor.new(field:field, works: works, mapper:mapper, rows: rows)
        processor.process
        errors += processor.errors;
        works_updated  += processor.works_updated
      end
      final_reporting(errors, works_updated)
    end
  end
end