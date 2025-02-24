# Serialize Work metadata as JSON
#
# This is pretty much our internal data format exposed in JSON.
#
# While we aspire for this to be a stable API for external partners, and will do our best
# to keep it so, significant internal data format changes will likely cause changes to
# this serialization. It's really an internal format exposed.
#
# Consumers could consider the OAI_DC serialization as more stable (although currently
# including fewer fields); we could add fields to that serialization with standard
# identifiers, or consider other future alternate standard serializations.
class WorkJsonSerializer
  include Alba::Resource
  include Rails.application.routes.url_helpers

  # set host for the inclusion of route helpers above. this is weird and under-documented by Rails.
  def default_url_options
    {
      host: ScihistDigicoll::Env.lookup(:app_url_base)
    }
  end


  # let's suggest our outward-facing friendlier_id as the main id, but also
  # let them see internal id why not
  attribute :id, &:friendlier_id
  attribute :internal_id, &:id

  # let's group the links in a `links` attribute; if this were json:api it would
  # be completely separate from attributes
  attribute :links do
    # * thumbnail: delegate to whatever WorkOaiDcSerialization is deciding is the thumbnail
    # * html_self: just hard-code cause we don't have access to route helpers here
    {
      img_thumbnail: WorkOaiDcSerialization.shareable_thumbnail_url(object),
      html_self: "#{ScihistDigicoll::Env.lookup!(:app_url_base)}/works/#{object.friendlier_id}"
    }
  end

  attributes :title, :additional_title, :format, :genre, :medium, :extent, :language,
    :provenance, :subject, :department, :series_arrangement,
    :rights, :rights_holder, :digitization_funder, :file_creator

  attribute :description do |work|
    DescriptionDisplayFormatter.new(work.description).format_plain
  end

  attribute :description_html do |work|
    DescriptionDisplayFormatter.new(work.description).format
  end

  attribute :published_at do |work|
    work.published_at&.utc&.iso8601
  end

  attribute :updated_at do |work|
    work.updated_at&.utc&.iso8601
  end


  many :creator do
    attributes :category, :value
  end

  many :date_of_work do
    attributes :start, :start_qualifier, :finish, :finish_qualifier, :note

    attribute :formatted do |date_of_work|
      DateDisplayFormatter.new([date_of_work]).display_dates.first
    end
  end

  many :place do
    attributes :category, :value
  end

  many :inscription do
    attributes :location, :text
  end

  many :related_link do
    attributes :url, :category, :label
  end

  many :additional_credit do
    attributes :role, :name
  end

  one :physical_container do
    attributes :box, :folder, :volume, :part, :page, :shelfmark, :reel

    attribute :formatted, &:display_as
  end


  # Serialize this in-line as an attribute, the fact that it's a relationship internally
  # via .oral_history_content is an implementation detail.
  attribute :interviewer_profile, if: Proc.new { |work| work.oral_history_content&.interviewer_profiles.present? } do |work|
    # can be multiple interviewer_profile, it's a to-many assoc
    work.oral_history_content.interviewer_profiles.collect do |profile|
      { name: profile.name, profile: profile.profile }
    end
  end

  # Serialize this in-line as an attribute, the fact that it's a relationship internally
  # via .oral_history_content is an implementation detail.
  attribute :interviewee_biography, if: Proc.new { |work| work.oral_history_content&.interviewee_biographies.present? } do |work|
    work.oral_history_content.interviewee_biographies.collect do |bio|
      IntervieweeBiographyJsonApiSerializer.new(bio).serializable_hash
    end
  end

  # Kind of hacky and custom-fit API for Max Planck Oral History consumption uses.
  attribute :oral_history_assets, if: Proc.new { |work| work.is_oral_history? } do |work|
    # only *published* transcript and front matter, give URLs to download assets.
    # Give internal URLs that will redirect to signed S3.
    work.members.select do |member|
      member.kind_of?(Asset) && member.published? && member.role.in?(["transcript", "front_matter"])
    end.map do |asset|
      {
        id: asset.friendlier_id,
        role: asset.role.to_s,
        content_type: asset.content_type,
        url: download_url(asset.file_category, asset),
        original_filename: asset.original_filename
      }
    end
  end


  class IntervieweeBiographyJsonApiSerializer
    #  include JSONAPI::Serializer
    include Alba::Resource

    attributes :name

    one :birth do
      attributes :date, :city, :state, :province, :country
    end

    one :death do
      attributes :date, :city, :state, :province, :country
    end

    many :school, key: :education do
      attributes :date, :institution, :degree, :discipline
    end

    many :job do
      attributes :institution, :role

      attribute :start_date, &:start
      attribute :end_date, &:end
    end

    many :honor do
      attributes :start_date, :end_date, :honor
    end
  end
end
