# frozen_string_literal: true

class Shrine
  module Plugins

    # This is based on the shrine upload_options plugin, but modified so that:
    #
    # * you regsiter upload_options that will apply to ALL storages used by the uploader,
    #   instead of having to register storage-specific.
    #
    # * an upload_options block gets the specific storage as an argument.
    #
    # It was copied and modified from shrine at v3.4.0: https://github.com/shrinerb/shrine/blob/v3.4.0/lib/shrine/plugins/upload_options.rb
    #
    # You may be interested in docs for the original shrine plugin at https://shrinerb.com/docs/plugins/upload_options
    #
    # And some discussion of these additonal features in my post at https://discourse.shrinerb.com/t/upload-options-plugin-for-dynamic-options-but-covering-more-than-one-storage/560
    #
    #     plugin :scihist_upload_options, proccessor: -> (io, options, storage_key) {
    #       if storage_key == :kithe_derivatives
    #          { acl: "public-read" }
    #       end
    #     }
    #
    module ScihistUploadOptions
      def self.configure(uploader, **opts)
        uploader.opts[:scihist_upload_options] ||= {}
        uploader.opts[:scihist_upload_options].merge!(opts)
      end

      module InstanceMethods
        private

        def _upload(io, **options)
          upload_options = get_upload_options(io, options)
byebug
          super(io, **options, upload_options: upload_options)
        end

        def get_upload_options(io, options)
          upload_options = opts[:scihist_upload_options][:proccessor] || {}
          upload_options = upload_options.call(io, options, storage_key) if upload_options.respond_to?(:call)
          upload_options = upload_options.merge(options[:scihist_upload_options]) if options[:scihist_upload_options]
          upload_options
        end
      end
    end

    register_plugin(:scihist_upload_options, ScihistUploadOptions)
  end
end
