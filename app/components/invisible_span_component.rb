# frozen_string_literal: true
# A component that displays an invisible span designed to be read by Javascript code in the browser and hidden from all users.
#   <%= InvisibleSpanComponent.new(klass:"no-more-images", contents: "No more images").display %>
#   should render as: <span class="no-more-images" style="display:none">No more images!</span>
#
class InvisibleSpanComponent < ApplicationComponent
  attr_accessor :klass, :contents

  def initialize(klass:, contents:"")
    @klass = klass
    @contents = contents
  end

  def call
    tag.span @contents, class: @klass, style: "display:none"
  end
end
