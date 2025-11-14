require 'open-uri'
require 'zip'

# Create a ZIP of full-size JPGs of all images in a work.
#
# Known limitation: If a work contains child works (rather than direct assets), only one single representative
# image for each child is included.
#
#     WorkZipCreator.new(work).create_zip
#
# Will return a ruby Tempfile that is NOT closed/unliked, up to caller to take care
# of it.
#
# Zipfile will have an attribution file added to it, as well as attribution text set
# as zip comment.
#
# Callback is a proc that takes keyword arguments `progress_total` and `progress_i` to receive progress info
# for reporting to user.
class GoogleArtsAndCultureZipCreator
  attr_reader :scope, :callback

  # @param callback [proc], proc taking keyword arguments progress_i: and progress_total:, can
  #   be used to update a progress UI.
  def initialize(scope, callback: nil)
    @scope = scope
    @callback = callback
  end


  def csv_file
    serializer = GoogleArtsAndCultureSerializer.new(scope)
    serializer.csv_tempfile
  end

  def self.filename_from_asset(asset)
    "#{DownloadFilenameHelper.filename_base_from_parent(asset)}.jpg"
  end

  # published members. pre-loads leaf_representative derivatives.
  # Limited to members whose leaf representative has a download_full derivative
  #
  # Members will have derivatives pre-loaded.
  def self.members_to_include(work)
    @members_to_include ||= work.
                            members.
                            includes(:leaf_representative).
                            where(published: true).
                            order(:position).
                            select do |m|
                              m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
                            end
  end


  # Returns a Tempfile. Up to caller to close/unlink tempfile when done with it.
  def create
    comment_file = tmp_comment_file!
    tmp_zipfile = tmp_zipfile!

    derivative_files = []

    Zip::File.open(tmp_zipfile.path, create: true) do |zipfile|

      # Add attribution as file and zip comment text
      zipfile.comment = comment_text
      zipfile.add("about.txt", comment_file)
      zipfile.add("manifest.csv", csv_file)

      @scope.includes(:leaf_representative).find_each do |work|
        puts "Starting work #{work.title}"
        self.class.members_to_include(work).each do |member|
          puts "   Starting member #{member.friendlier_id}"
          filename = self.class.filename_from_asset(member)
          uploaded_file = file_to_include(member.leaf_representative)
          file_obj = uploaded_file.download
          derivative_files << file_obj
          entry = ::Zip::Entry.new(zipfile.name, filename, compression_method: ::Zip::Entry::STORED)
          zipfile.add(entry, file_obj)
          puts "   Added asset #{member.friendlier_id}"
        end
        puts "Added work #{work.title}"
      end
      puts "Got throguh the scope."
    end
    puts "About to open the zip file"
    tmp_zipfile.open
    puts "About to return the zip file"
    return tmp_zipfile
  ensure
    (derivative_files || []).each do |tmp_file|
      tmp_file.close
      tmp_file.unlink
    end

    if comment_file
      comment_file.close
      comment_file.unlink
    end
  end

  private

  # @returns [Shrine::UploadedFile]
  def file_to_include(asset)
    if asset.content_type == "image/jpeg"
      asset.file
    else
      asset.file_derivatives(:download_full)
    end
  end

  def tmp_zipfile!
    Tempfile.new(["GAC_download_#{'asdasd'}", ".zip"]).tap { |t| t.binmode }
  end

  def comment_text
    @comment_text ||= <<~EOS
      Courtesy of the Science History Institute, https://sciencehistory.org
      Prepared on #{Time.now}
    EOS
  end

  def tmp_comment_file!
    Tempfile.new("zip-comment").tap do |file|
      file.write(comment_text)
      file.rewind
    end
  end
end
