class AtomEntryComponent < ApplicationComponent
  attr_reader :model

  def initialize(model)
    raise ArgumentError.new("#{self.class} requires non-nil model argument") unless model
    raise ArgumentError.new("#{self.class} only supports Work and Collection, not `#{model.class.name}`") unless model.kind_of?(Work) || model.kind_of?(Collection)
    @model = model
  end

  private

  def thumbnail_url
    WorkOaiDcSerialization.shareable_thumbnail_url(model)
  end

  def model_html_url
    if model.kind_of?(Work)
      work_url(model)
    else
      collection_url(model)
    end
  end

  def model_alternate_links
    if model.kind_of?(Work)
      [
        {
          type: "application/xml",
          title: "OAI-DC metadata in XML",
          href: work_url(model, format: "xml")
        },
        {
          type: "application/json",
          title: "local non-standard metadata in JSON",
          href: work_url(model, format: "json")
        }
      ]
    else
      # we don't currently have .xml and .json metadata links for Collections
      []
    end
  end
end
