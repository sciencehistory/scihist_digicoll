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
class WorkZipCreator
  attr_reader :work, :callback

  # @param work [Work] Work object, it's members will be put into a zip
  # @param callback [proc], proc taking keyword arguments progress_i: and progress_total:, can
  #   be used to update a progress UI.
  def initialize(work, callback: nil)
    @work = work
    @callback = callback
  end

  # Returns a Tempfile. Up to caller to close/unlink tempfile when done with it.
  def create
    comment_file = tmp_comment_file!
    tmp_zipfile = tmp_zipfile!

    # Stream entries into the zip one at a time with Zip::OutputStream, deleting each
    # downloaded file right after it's written, and reusing one read buffer.
    #
    # This is an attempt to reduce memory allocations and RAM usage compared to
    # Zip::File.open API.
    Zip::OutputStream.open(tmp_zipfile.path) do |zos|
      zos.comment = comment_text
      add_entry(zos, "about.txt", comment_file, compression_method: ::Zip::Entry::DEFLATED)

      members_to_include.each_with_index do |member, index|
        filename = "#{format '%03d', index+1}-#{DownloadFilenameHelper.filename_base_from_parent(member)}.jpg"

        uploaded_file = file_to_include(member.leaf_representative)

        # Download to local disk first; we couldn't get streaming straight from remote storage
        # working with shrine api's.
        file_obj = uploaded_file.download
        begin
          # "STORED", not "DEFLATE", since our JPGs won't compress anyway, save the CPU.
          add_entry(zos, filename, file_obj, compression_method: ::Zip::Entry::STORED)
        ensure
          file_obj.close
          file_obj.unlink
        end

        # We don't really need to update on every page, the front-end is only polling every two seconds anyway
        if callback && (index % 3 == 0 || index >= members_to_include.count - 1)
          callback.call(progress_total: members_to_include.count, progress_i: index + 1)
        end
      end
    end

    # tell the Tempfile to (re)open so it has a file handle open that can see what ruby-zip wrote
    tmp_zipfile.open

    return tmp_zipfile
  ensure
    if comment_file
      comment_file.close
      comment_file.unlink
    end
  end

  private

  READ_BUFFER_SIZE = 128 * 1024

  # Written to re-use a single string buffer per-call, to try to reduce
  # ruby allocations and thus RAM usage before the GC can get it.
  def add_entry(zos, name, io, compression_method:)
    zos.put_next_entry(name, '', ::Zip::ExtraField.new, compression_method)
    io.rewind
    buffer = String.new(capacity: READ_BUFFER_SIZE)
    while io.read(READ_BUFFER_SIZE, buffer)
      zos << buffer
    end
  end

  # @returns [Shrine::UploadedFile]
  def file_to_include(asset)
    if asset.content_type == "image/jpeg"
      asset.file
    else
      asset.file_derivatives(:download_full)
    end
  end

  # published members. pre-loads leaf_representative derivatives.
  # Limited to members whose leaf representative has a download_full derivative
  #
  # Members will have derivatives pre-loaded.
  def members_to_include
    @members_to_include ||= work.
                            members.
                            includes(:leaf_representative).
                            where(published: true).
                            order(:position).
                            select do |m|
                              m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
                            end
  end

  def tmp_zipfile!
    Tempfile.new(["zip-#{work.friendlier_id}", ".zip"]).tap { |t| t.binmode }
  end

  def comment_text
    @comment_text ||= <<~EOS
      Courtesy of the Science History Institute, https://sciencehistory.org

      #{work.title}
      #{ScihistDigicoll::Env.lookup!(:app_url_base)}/works/#{work.friendlier_id}

      Prepared on #{Time.now}
    EOS
  end

  def tmp_comment_file!
    Tempfile.new("zip-#{work.friendlier_id}-comment").tap do |file|
      file.write(comment_text)
      file.rewind
    end
  end
end
