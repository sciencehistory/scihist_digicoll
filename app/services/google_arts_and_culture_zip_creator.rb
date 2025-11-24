require 'open-uri'
require 'zip'

class GoogleArtsAndCultureZipCreator
  include GoogleArtsAndCultureSerializerHelper
  attr_reader :scope, :callback

  def initialize(scope, callback: nil)
    @scope = scope
    @callback = callback
  end

  # Returns a Tempfile. Up to caller to close/unlink tempfile when done with it.
  def create
    tmp_zipfile = tmp_zipfile!
    derivative_files = []
    Zip::File.open(tmp_zipfile.path, create: true) do |zipfile|
      zipfile.add("manifest.csv", csv_file)
      if true
        @scope.includes(:leaf_representative).find_each do |work|
          members_to_include(work).each do |member|
            filename = filename_from_asset(member)
            uploaded_file = file_to_include(member.leaf_representative)
            file_obj = uploaded_file.download
            derivative_files << file_obj
            entry = ::Zip::Entry.new(zipfile.name, filename, compression_method: ::Zip::Entry::STORED)
            zipfile.add(entry, file_obj)
            # puts "added #{filename}"
          end
        end
      end
    end
    tmp_zipfile.open
    return tmp_zipfile
  ensure
    (derivative_files || []).each do |tmp_file|
      tmp_file.close
      tmp_file.unlink
    end

  end

  def csv_file
    serializer = GoogleArtsAndCultureSerializer.new(scope)
    serializer.csv_tempfile
  end

  private

  def tmp_zipfile!
    Tempfile.new(["GAC_download", ".zip"]).tap { |t| t.binmode }
  end
end
