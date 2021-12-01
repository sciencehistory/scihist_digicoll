class Work

  # A little value class for a piece of text and an index numer/label --
  # the things we need to display an individual
  # asset-page's worth of transcription or translation text
  class TextPage
    attr_reader :asset, :image_number, :text

    # assets passed in may not be all of a Work's members, maybe we've already
    # filtered to just the public ones or whatever.
    #
    # We just attach indexes to them in order, we have nothing better to call
    # them at present than "Image 1", 'Image 2" etc  -- but maybe can
    # do something more sophisticated later?
    #
    # @param members [Array<Kithe::Model>] Array of "members", Works or Assets.
    #   At the moment, Works are skipped, only Assets are numbered in order.
    #
    # @param accessor [Symbol] generally `:transcription` or `:english_translation`,
    #    method to get the text from.
    def self.compile(members, accessor:)
      members.collect.with_index do |member, i|
        if member.kind_of?(Asset) && member.send(accessor).present?
          TextPage.new(
            member,
            image_number: i+1,
            text: member.send(accessor)
          )
        end
      end.compact
    end

    def initialize(asset, image_number:, text:)
      @asset = asset
      @image_number = image_number
      @text = text
    end

    def friendlier_id
      asset.friendlier_id
    end

    def page_label
      "Image #{image_number}"
    end
  end
end
