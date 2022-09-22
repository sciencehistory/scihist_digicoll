class AtomEntryComponent < ApplicationComponent
  attr_reader :model

  def initialize(model)
    raise ArgumentError.new("#{self.class} requires non-nil model argument") unless model
    @model = model
  end

  private

  def thumbnail_url
    WorkOaiDcSerialization.shareable_thumbnail_url(model)
  end

end
