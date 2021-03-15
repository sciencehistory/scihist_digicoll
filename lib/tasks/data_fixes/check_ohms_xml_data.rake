namespace :scihist do
  namespace :data_fixes do
    # bundle exec rake scihist:data_fixes:check_ohms_xml_data
    desc "validate all OHMS xml"
    task :check_ohms_xml_data => [:environment] do


      OralHistoryContent.find_each do |model|
        next if model.ohms_xml_text.nil?
        validator = OralHistoryContent::OhmsXmlValidator.new(model.ohms_xml_text)
        next if validator.valid?
        puts "****"
        puts "#{model.work.title} ( #{model.work.friendlier_id} ) has the following errors:"
        puts validator.errors&.join ("\n")
      end
    end
  end
end
