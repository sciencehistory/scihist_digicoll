module OralHistory
  class BiographicalComponent < ApplicationComponent
    attr_reader :biography

    def initialize(biography)
      unless biography.kind_of?(IntervieweeBiography)
        raise TypeError.new("Must be IntervieweeBiography")
      end
      @biography = biography
    end

    def render?
      has_biographical_info?
    end

    def schools
      @schools ||= (biography.school || []).sort_by { |school| school&.date || "0" }
    end

    def honors
      @honors ||= (biography.honor || []).sort_by { |honor| honor&.start_date || "0" }
    end

    # Hash where key is institution, value is array of jobs at that institution.
    #
    # Jobs within an institution are sorted by date.
    #
    # Institution  Keys in Hash should be inserted in order of FIRST date in that institution.
    def grouped_jobs
      @grouped_jobs ||= begin
        # groups will be an array of pairs, like [ [institution, [array]], [institution [array]], ...]
        groups  = (biography&.job || []).group_by {|job| job.institution }.to_a

        groups.each do |institution, jobs|
          jobs.sort_by! {|job| job.start || "0" }
        end

        groups.sort_by! { |institution, jobs| jobs.first&.start || "0" }

        groups.to_h
      end
    end

    def birth_info
      @birth_info ||= formatted_date_and_place(biography.birth)
    end

    def death_info
      @death_info ||=  formatted_date_and_place(biography.death)
    end

    def has_biographical_info?
      return false unless biography.present?

      birth_info.present? || death_info.present? || schools.present? || grouped_jobs.present? || honors.present?
    end

    def sanitized_honor_string(honor_str)
      DescriptionSanitizer.new.sanitize(honor_str)&.html_safe
    end


    # See discussion at https://github.com/sciencehistory/scihist_digicoll/issues/2045
    def formatted_job_dates(start_date, end_date)
      if end_date.blank?
        # A blank end date means the job is still considered current.
        "#{FormatSimpleDate.new(start_date).display} to present"
      else
        # Note: FormatSimpleDate will only show the start date if start and end are identical.
        FormatSimpleDate.new(start_date, end_date).display
      end
    end

    private


    # @param date_and_place [OralHistoryContent::DateAndPlace]
    def formatted_date_and_place(date_and_place)
      return nil if date_and_place.nil?

      date = FormatSimpleDate.new(date_and_place.date).display.presence
      place = [date_and_place.city, date_and_place.state_name, date_and_place.province_name, date_and_place.country_name].compact.join(", ").presence

      items = safe_join(
        [date, place].compact.collect { |v| content_tag("li", v, class: "attribute")}
      )
      if items.present?
        content_tag("ul", items)
      else
        nil
      end
    end
  end
end
