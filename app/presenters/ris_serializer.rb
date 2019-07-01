# Renders an RIS format citation from a Work.
#
# @example
#
# RisSerializer.new(work).to_ris

class RisSerializer
  RIS_LINE_END = "\r\n"
  RIS_END_RECORD = "ER  -#{RIS_LINE_END}"

  def initialize(the_work)
    raise ArgumentError, 'Argument should be a Work' unless the_work.is_a? Work
    @work = the_work
    @citable_attributes = CitableAttributes.new(@work)
  end

  def self.formatted_ris_date(year:, month: nil, day: nil, extra: nil)
    str = year.to_s

    str += "/"
    if month.present?
      str += "%02i" % month.to_i
    end

    str += "/"
    if day.present?
      str += "%02i" % day.to_i
    end

    str += "/"
    if extra.present?
      str += extra
    end

    str
  end

  # # RIS fields not including type. Values can be arrays or single elements.
  def ris_hash
    return @ris_hash if defined?(@ris_hash)
    @ris_hash ||= {
      # Theoretically "DB" is 'name of database' and "DP" is "database provider"
      # Different software uses one or the other for "Archive:". We use the plain
      # institute name for both, in line with rebrand style guide.
      "DB" => "Science History Institute",
      "DP" => "Science History Institute",
      # M2 is 'extra' notes field
      "M2" => m2,

      "TI" => @citable_attributes.title,
      "T2" => @citable_attributes.container_title,

      "ID" => @work.friendlier_id,
      "AU" => @citable_attributes.authors_formatted,
      "PB" => @citable_attributes.publisher,
      "CY" => @citable_attributes.publisher_place,
      "DA" => ris_date,
      "YR" => ris_date_year,

      "M3" => @citable_attributes.medium,

      # archival location is according to wikipedia "AV". Endnote uses "VL" (volume) for this though.
      # And Zotero uses "AN" (accession number)!
      "AV" => @citable_attributes.archive_location,
      "VL" => @citable_attributes.archive_location,
      "AN" => @citable_attributes.archive_location,

      "UR" => @citable_attributes.url,

      "AB" => @citable_attributes.abstract,
      "KW" => kw,
      "LA" => la,
    }
  end

  def to_ris

    return @to_ris if defined?(@to_ris)

    @to_ris ||= begin
      lines = []
      # TY needs to be first
      lines << "TY  - #{ris_type}"

      ris_hash.each_pair do |tag, value|
        Array(value).each do |v|
          lines << "#{tag}  - #{v}"
        end
      end

      lines << RIS_END_RECORD
      lines.join(RIS_LINE_END)
    end
  end

  def genre
    @work.genre || []
  end

  # # Limited ability to map to RIS types -- 'manuscript' type seems to get
  # # the best functionality for archival fields in most software, so we default to
  # # that and use that in many places maybe we COULD have something more specific.

  def ris_type
    return @ris_type if defined?(@ris_type)

    @ris_type ||= begin
      if @citable_attributes.treat_as_local_photograph?
        # we're treating as a photo taken by us, "ART" is best we've got in RIS?
        "ART"
      elsif @citable_attributes.container_title.present?
        # basically the only way RIS-handling things are going to handle a
        # container title in any reasonable way, I think.
        "CHAP"
      elsif genre.include?('Manuscripts')
        "MANSCPT"
      elsif (genre & ['Personal correspondence', 'Business correspondence']).present?
        "PCOMM"
      elsif (genre & ['Rare books', 'Sample books']).present?
        "BOOK"
      elsif genre.include?('Documents') && @work.title =~ /report/i
        "RPRT"
      elsif  @work.department == ["Archives"]
        # if it's not one of above known to use archival metadata, and it's in
        # Archives, insist on Manuscript.
        "MANSCPT"
      elsif (genre & %w{Paintings}).present?
        "ART"
      elsif genre.include?('Slides')
        "SLIDE"
      elsif genre.include?('Encyclopedias and dictionaries')
        "ENCYC"
      else
        "MANSCPT"
      end
    end
  end

  # # zotero 'extra'. endnote?
  def m2
    return @m2 if defined?(@m2)
    @m2 ||= begin
      result = "Courtesy of Science History Institute."
      if @work.rights.present?
        # Note: @work.rights is a string, not an array as in Sufia.
        rights_holder_string = @work.rights_holder.present? ? ", #{@work.rights_holder.try(:first)}" : ""
        result = result + "  Rights: " + RightsTerms.label_for(@work.rights) + rights_holder_string
      end
      result
    end
  end

  # # date in RIS format
  def ris_date
    return @ris_date if defined?(@ris_date)

    @ris_date ||= begin
      if start_d = @citable_attributes.date && @citable_attributes.date.parts.first
        self.class.formatted_ris_date(year: start_d.year, month: start_d.month, day: start_d.day)
      end
    end
  end

  def ris_date_year
    return @ris_date_year if defined?(@ris_date_year)

    @ris_date_year ||= begin
      if start_d = @citable_attributes.date && @citable_attributes.date.parts.first
        start_d.year
      end
    end
  end

  # # subjects aren't in CitableAttributes yet, maybe they should be if we
  # # end up using csl-data for zotero export ever.
  # #
  # # Returns an array cause RIS kw is a rare repeatable one.
  def kw
    return @kw if defined?(@kw)

    @kw ||= begin
      @work.subject
    end
  end

  # # languages aren't in CitableAttributes yet, maybe they should be if we
  # # end up using csl-data for zotero export ever.
  # #
  # # RIS la is not repeatable, we join multiple with comma
  def la
    return @la if defined?(@la)

    @la ||= @work.language.join(", ")
  end
end