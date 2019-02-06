require "shrine"
require "shrine/storage/file_system"
require "down"

class FileSetImporter < Importer

  if ENV['FEDORA_USERNAME'].nil? || ENV['FEDORA_PASSWORD'].nil?
    @@fedora_credentials = {}
  else
    @@fedora_credentials ||= {username: ENV['FEDORA_USERNAME'], password: ENV['FEDORA_PASSWORD']}
  end

  def initialize(path, options = {})
    super
    if Rails.env.development?
      @seconds_to_wait_after_importing = 2
    else
      @seconds_to_wait_after_importing = 10
    end
  end

  # If we know the username and password for Fedora,
  # add them to the file URL.
  def edit_metadata()
    if @@fedora_credentials != {}
      basic_download_url = @metadata['file_url']
      credentials = "http://#{@@fedora_credentials[:username]}:#{@@fedora_credentials[:password]}@"
      @metadata['file_url'] = basic_download_url.sub('http://', credentials)
    end
  end


  def ok_to_skip_this_item()
    return false if preexisting_item.nil?
    if preexisting_item.sha1 == @metadata['sha_1']
      puts "The checksums matched; ok to skip this item."
      @seconds_to_wait_after_importing = 0
      return true
    end
    false
  end

  def how_long_to_sleep()
    @seconds_to_wait_after_importing
  end

  def populate()
    # @new_item is an unsaved Asset

    # this _should_ tell @new_item's shrine uploader to do promotion inline instead of
    # kicking off a background job.
    @new_item.file_attacher.set_promotion_directives(promote: "inline")

    # Now the promotion is happening inline, but the promotion will ordinarily
    # kick off yet another job for derivatives creation. For now, let's tell it
    # NOT to do derivatives creation at all.

    # @new_item.file_attacher.set_promotion_directives(create_derivatives: false)
    @new_item.file_attacher.set_promotion_directives(create_derivatives: "inline")


    @new_item.file = { "id" => metadata['file_url'], "storage" => "remote_url"}

    super
  end

  def self.importee()
    return 'FileSet'
  end

  def self.destination_class()
    return Asset
  end
end
