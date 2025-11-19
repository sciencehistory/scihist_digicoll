module GoogleArtsAndCultureSerializerHelper

  # Work

  def subitem_id(work)
    not_applicable
  end


  # Should we treat works with only one asset differently? Probably not.
  def filespec(work)
    not_applicable
  end

  def order_id(work)
    not_applicable
  end

  def url_text(work)
    'Science History Institute Digital Collections'
  end

  def url(work)
    app_url_base + Rails.application.routes.url_helpers.work_path(work.friendlier_id)
  end

  def external_id(work)
    work.external_id.map(&:value)
  end

  def creator(work)
    work.creator.find_all { |creator| creator.category.to_s != "publisher" }.map(&:value)
  end

  def publisher(work)
    work.creator.find_all { |creator| creator.category.to_s == "publisher" }.map(&:value).join(", ")
  end

  def place(work)
    work.place.map(&:value)
  end

  def filetype(work)
    'Sequence'
  end


  # If either dateCreated:display
  # or dateCreated:end are non-empty then
  # dateCreated:start must also be non-empty.
  # To not set a date leave all three fields empty.

  # TODO -- how do we handle multiple dates?
  def date_of_work(work)
    unless min_date(work).present?
      no_value
    else
      DateDisplayFormatter.new(work.date_of_work).display_dates.join("; ")
    end
  end

  def min_date(work)
    DateIndexHelper.new(work).min_date.to_s
  end

  def max_date(work)
    DateIndexHelper.new(work).max_date.to_s
  end

  def format_date(date)
    date.year.to_s
  end

  def description(work)
    DescriptionDisplayFormatter.new(work.description).format_plain
  end

  def physical_container(work)
    return no_value if work.physical_container.nil?
    work.physical_container.attributes.map {|l, v | "#{l.humanize}: #{v}" if v.present? }.compact
  end

  def additional_credit(work)
     work.additional_credit.map{ |item| "#{item.role}:#{item.name}" }
  end

  def created(work)
    I18n.l work.created_at, format: :admin
  end

  def last_modified(work)
    I18n.l work.updated_at, format: :admin
  end

  # Asset

  def asset_filetype(asset)
    if asset.content_type&.start_with?("video/")
        'Video'
      elsif asset.content_type&.start_with?("image/")
        'Image'
      else
        not_applicable
      end
  end

  def filename_from_asset(asset)
    if asset&.file&.url.nil?
      no_value
    else
      File.basename(URI.parse(asset.file.url(public: true)))
    end
  end

  # Other

  def padding
    test_mode ? 'PADDING' : ''
  end

  def no_value
    test_mode ? 'NO_VALUE' : ''
  end

  def not_applicable
    test_mode ? 'N/A' : ''
  end
end
