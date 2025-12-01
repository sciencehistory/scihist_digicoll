module GoogleArtsAndCultureSerializerHelper
  def members_to_include(work)
    work.members.
    includes(:leaf_representative).
    where(published: true).
    where(type: "Asset").
    order(:position).
    select do |m|
      m.leaf_representative.content_type == "image/jpeg" || m.leaf_representative&.file_derivatives(:download_full)
    end
  end

  
  # @returns [Shrine::UploadedFile]
  def asset_file(asset)
    if asset.content_type == "image/jpeg"
      asset.file
    else
      asset.file_derivatives(:download_full)
    end
  end

  def asset_filetype(asset)
    if asset.content_type&.start_with?("video/")
      'Video' # currently unavailable
    elsif asset.content_type&.start_with?("image/")
      'Image'
    else
      not_applicable
    end
  end

  def filetype(work)
    'Sequence'
  end

  def asset_filename(asset)
    return no_value if asset&.file&.url.nil?
    "#{DownloadFilenameHelper.filename_base_from_parent(asset)}.jpg"
  end

  def file_name(work)
    not_applicable
  end

  def subitem_id(work)
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

  def app_url_base
    @app_url_base ||= ScihistDigicoll::Env.lookup!(:app_url_base)
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

  def rights(work)
    RightsTerm.label_for(work.rights)
  end

  def test_mode
    false
  end

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
