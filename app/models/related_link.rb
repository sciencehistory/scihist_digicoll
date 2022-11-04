# AttrJson embedded model for links, with url and label and category
#
# For now "related works" are in here too, although we may extract to an actual
# work to work association or other separate modelling.
class RelatedLink
  include AttrJson::Model

  CATEGORY_VALUES = %w{finding_aid institute_article institute_podcast
                      institute_video
                      institute_biography institute_blog_post institute_libguide
                      related_work other_external other_internal}

  RELATED_WORK_PREFIX_RE = %r{\A\s*https?://digital\.sciencehistory\.org/works}

  attr_json :url, :string
  attr_json :category, :string
  attr_json :label, :string

  validates_presence_of :category, :url

  validates :category, inclusion:
      { in: CATEGORY_VALUES,
        allow_blank: true,
        message: "%{value} is not a valid category" }


  validate :validate_url, :validate_related_work_url

  private
  def validate_url
    if url && !ScihistDigicoll::Util.valid_url?(url)
      errors.add(:url, "must be a valid URL")
    end
  end

  def validate_related_work_url
    if category == "related_work" && !(RELATED_WORK_PREFIX_RE =~ url)
      errors.add(:url, "for related work must be to https://digital.sciencehistory.org/works/..")
    end
  end

end
