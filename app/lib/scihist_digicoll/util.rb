# frozen_string_literal: true

module ScihistDigicoll
  module Util
    # inspired by code at
    # https://github.com/perfectline/validates_url/blob/b170db5a211b7e277c76727a46559c36b989e430/lib/validate_url.rb
    #
    # We make sure it's http or https, and the domain name has at least one dot in it.
    def self.valid_url?(str)
      uri = URI.parse(str)
      return !!(uri && uri.host && ["http", "https"].include?(uri.scheme) && uri.host.include?('.'))
    rescue URI::InvalidURIError
      return false
    end

    # Just take a bib number and produce a URL to our OPAC, using opac link template
    # from ENV.
    def self.opac_url(bib_number)
      ScihistDigicoll::Env.lookup(:opac_link_template).sub("%s", ERB::Util.url_encode(bib_number))
    end

    # Turn a content-type into a string we can show to a user, like 'application/pdf' to 'PDF'.
    #
    # For now, it's kind of rough, and relies on types registered with Rails Mime::Type
    # (see config/initializers/mime_types.rb), and assumes all caps of the extension is good.
    #
    # Maybe we should use explicit i18n instead.
    #
    # If nothing found registered with Rails Mime::Type, will return input.
    def self.humanized_content_type(content_type)
      return content_type if content_type.blank?

      mime_obj = Mime::Type.lookup(content_type)
      return content_type unless mime_obj && mime_obj.symbol

      mime_obj.symbol.to_s.upcase
    end

    # Quite similar to Rails' ActiveSupport::NumberHelper.number_to_human_size
    # But it turns out that Rails `number_to_human_size` is pretty expensive, expensive
    # enough to be a huge problem when we are calling this for each derivative for each member page
    # on a work page when displaying.
    #
    # So this is a much simpler version, that doens't get all the edge cases quite as nice,
    # or handle significant digits as nicely, and doesn't do I81n for units (that is
    # perhaps the main slowdown in Rails), but works quite good enough and is so much faster.
    #
    # Implementation cribbed and adapted from a StackOverflow answer somewhere.
    #
    #   ScihistDigicoll::Util.simple_bytes_to_human_string
    def self.simple_bytes_to_human_string(size)
      return nil if size.blank?

      # Technically since we are using 1024-base instead of 1000,
      # we should use the correctly standardized KiB MiB etc.
      # But to be consistent with Rails, we'll use the technically wrong
      # but familiar legacy KB MB etc. (Which technically should refer to 1000-base)
      #units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'Pib', 'EiB']
      units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB']

      return '0.0 B' if size == 0
      exp = (Math.log(size) / Math.log(1024)).to_i
      exp += 1 if (size.to_f / 1024 ** exp >= 1024 - 0.05)
      exp = 6 if exp > 6

      display_number = size.to_f / 1024 ** exp
      display_units  = units[exp]

      # Try to stick to no more than 3 significant digits; and not show `.0`.
      decimal_places = (display_number > 99 || (display_number % 1 == 0)) ? 0 : 1

      "%.#{decimal_places}f %s" % [display_number, display_units]
    end

    # Attempt to implement a convenience for ActiveRecord find_each that is more
    # memory efficient, using less RAM.
    #
    # @example
    #    ScihistDigicoll::Util.find_each( Asset.where(something)) do |record|
    #       something_with record
    #    end
    #
    # We default batch size smaller than default 200, aggressively GC.start, and use ActiveRecord.uncached
    # just in case.
    def self.find_each(active_record_scope, batch_size: 200)
      # ActiveRecord should already be disabling query cache for find_each, but
      # let's go overboard and force it extra just in case.
      active_record_scope.uncached do
        active_record_scope.find_in_batches(batch_size: batch_size) do |batch|
          # Aggressively GC any previous batch
          GC.start

          batch.each do |record|
            yield record
          end
        end
      end
    end
  end
end
