namespace :scihist do
  desc """
    Downloads images and a description so they can be sent to Gemini
    so that it can prepare HOCR for them.

    Example:

    WORK_FRIENDLIER_ID='8npkswk' \
    IMAGES_LOCAL_DIR='/where/to/put/images' \
    bundle exec rake scihist:prepare_hocr_request
  """
  task :prepare_hocr_request => :environment do
    images_local_dir = ENV['IMAGES_LOCAL_DIR']
    work_friendlier_id = ENV['WORK_FRIENDLIER_ID']


    unless images_local_dir.present? && work_friendlier_id.present?
      abort "Please enter a local directory and a work to add HOCR to."
    end
    work = Work.find_by_friendlier_id(work_friendlier_id)
    Dir.mkdir("#{images_local_dir}/#{work.friendlier_id}")

    assets = work.
      members.
      includes(:leaf_representative).
      where(published: true).
      order(:position).
      select do |m|
        m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
      end


    assets.each_with_index do |asset, index|
      filename = "#{format '%04d', index+1}-#{asset.friendlier_id}.jpg"
      File.open("#{images_local_dir}/#{work.friendlier_id}/#{filename}", "wb") do |out|
        IO.copy_stream(asset.file_derivatives[:download_large].to_io, out)
      end
    end
    File.open("#{images_local_dir}/#{work.friendlier_id}/description.txt", "wb") do |out|
      out.write work.description
    end

  end



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
