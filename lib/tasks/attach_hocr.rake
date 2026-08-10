namespace :scihist do
  desc """
    WORK_FRIENDLIER_ID='8npkswk' \
    HOCR_LOCAL_DIR='/Users/erubeiz/Desktop/2026 HOCR/gemini_api_experiment/v_4/output' \
    bundle exec rake scihist:attach_hocr
  """
  task :attach_hocr => :environment do

    hocr_local_dir = ENV['HOCR_LOCAL_DIR']
    work_friendlier_id = ENV['WORK_FRIENDLIER_ID']
    
    unless hocr_local_dir.present? && work_friendlier_id.present?
      abort "Please enter a local directory and a work to add HOCR to."
    end
    files_to_attach = Dir.glob("#{hocr_local_dir}/*.hocr")
    
    unless files_to_attach.present?
      abort "Did not find any hocr files in directory #{hocr_local_dir}."
    end

    work = Work.find_by_friendlier_id(work_friendlier_id)

    assets = work.members
    unless assets.count == files_to_attach.count
      abort "Wrong number of files."
    end

    file_map = assets.map { |a| [
      a.friendlier_id,
      files_to_attach.find { |f| f.include? a.friendlier_id }
    ] }.to_h

    "HOCR files we want to attach:"
    pp file_map

    assets.each do |asset|
      friendlier_id = asset.friendlier_id
      path = file_map[friendlier_id]
      begin
        hocr_string = File.read(path)
        parsed_hocr = Nokogiri::XML(hocr_string) { |config| config.strict }
        unless parsed_hocr.css(".ocr_page").length == 1
          abort "This HOCR file isn't valid  - no ocr_page element found"
        end
      rescue Nokogiri::XML::SyntaxError => e
        puts "=== ERROR OCCURRED ==="
        puts "Class: #{e.class}"
        puts "Message: #{e.message}"
        puts "Backtrace:"
        puts e.backtrace.join("\n")
        abort "This HOCR file isn't valid  -  syntax error."
      end
      puts "Found valid hocr for #{friendlier_id}"

    end


    puts "Attach these files to '#{work.title}' ? (y/n)"
    input = STDIN.gets.chomp.to_s.strip.downcase
    unless input == 'y' || input == 'yes'
      abort "Have a nice day."
    end

    # do an asset transaction here
    assets.each do |asset|
      friendlier_id = asset.friendlier_id
      path = file_map[friendlier_id]
      puts "Attaching hocr to #{friendlier_id}."
      hocr_string = File.read(path)
      asset.update!({hocr: hocr_string, suppress_ocr: false, ocr_admin_note: nil})
    end

  end
end
