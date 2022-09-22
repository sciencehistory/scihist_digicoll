xml.entry("xmlns:media" => "http://search.yahoo.com/mrss/") do
  xml.title model.title

  xml.updated (model.updated_at&.iso8601 || Time.current.iso8601)

  xml.id work_url(model)
  xml.link "rel" => "alternate", "type" => "text/html", "href" => work_url(model)

  xml.link rel: "alternate", type: "application/xml", title: "OAI-DC metadata in XML", href: work_url(model, format: "xml")
  xml.link rel: "alternate", type: "application/json", title: "local non-standard metadata in JSON", href: work_url(model, format: "json")

  if thumbnail_url
    xml.media :thumbnail, thumbnail_url
  end

  xml.summary "type" => "html" do
    xml.text! DescriptionDisplayFormatter.new(model.description).format
  end
end
