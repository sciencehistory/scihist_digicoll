xml.entry("xmlns:media" => "http://search.yahoo.com/mrss/") do
  xml.title model.title

  xml.updated (model.updated_at&.iso8601 || Time.current.iso8601)

  xml.id work_url(model)
  xml.link "rel" => "alternate", "type" => "text/html", "href" => model_html_url

  model_alternate_links.each do |link_hash|
    xml.link rel: "alternate", **link_hash
  end

  if thumbnail_url
    xml.media :thumbnail, thumbnail_url
  end

  xml.summary "type" => "html" do
    xml.text! DescriptionDisplayFormatter.new(model.description).format
  end
end
