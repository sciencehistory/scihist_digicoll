require 'open-uri'

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
  def create_zip
    comment_file = tmp_comment_file!
    tmp_zipfile = tmp_zipfile!

    derivative_files = []

    Zip::File.open(tmp_zipfile.path, Zip::File::CREATE) do |zipfile|
      # Add attribution as file and zip comment text
      zipfile.comment = comment_text
      zipfile.add("about.txt", comment_file)

      members_to_include.each_with_index do |member, index|
        filename = "#{format '%03d', index+1}-#{work.friendlier_id}-#{member.friendlier_id}.jpg"

        # We want to add to zip as "STORED", not "DEFLATE", since our JPGs
        # won't compress under DEFLATE anyway, save the CPU. Ruby zip does not
        # give us a GREAT api to do that, but it gives us a way.
        #
        # https://github.com/rubyzip/rubyzip/blob/05af1231f49f2637b577accea2b6b732b7204bbb/lib/zip/file.rb#L271
        # https://github.com/rubyzip/rubyzip/blob/05af1231f49f2637b577accea2b6b732b7204bbb/lib/zip/entry.rb#L53
        derivative = member.leaf_representative.derivative_for(:download_full)

        # We can get a file-like object from our shrine attachment, that ruby zip will accept.
        # This may result in writing all the bytes to disk locally as a temp cache, even though
        # we don't really need to, oh well. We do need to keep track of the files to `close` them
        # in ensure later.
        derivative_file = derivative.file.open
        derivative_files << derivative_file

        entry = ::Zip::Entry.new(zipfile.name, filename, nil, nil, nil, nil, ::Zip::Entry::STORED)
        zipfile.add(entry, derivative_file)

        # We don't really need to update on every page, the front-end is only polling every two seconds anyway
        if callback && (index % 3 == 0 || index >= members_to_include.count - 1)
          callback.call(progress_total: members_to_include.count, progress_i: index + 1)
        end
      end
    end

    return tmp_zipfile
  ensure
    derivative_files.each(&:close) if derivative_files

    if comment_file
      comment_file.close
      comment_file.unlink
    end
  end

  private

  # published members. pre-loads leaf_representative derivatives.
  # Limited to members whose leaf representative has a download_full derivative
  #
  # Members will have derivatives pre-loaded.
  def members_to_include
    @members_to_include ||= work.
                            members.
                            with_representative_derivatives.
                            where(published: true).
                            select do |m|
                              deriv = m.leaf_representative&.derivative_for(:download_full)
                              deriv && deriv.file.present?
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
