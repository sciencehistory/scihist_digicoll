class OralHistoryBiographicalDisplay < ViewModel
  valid_model_type_names "Work"

  alias_method :work, :model

  def display
    render "/presenters/oral_history_biographical_display", model: model, view: self
  end

  def oral_history_content
    work.oral_history_content!
  end

  def schools
    @schools ||= (work.oral_history_content&.interviewee_school || []).sort_by(&:date)
  end

  def honors
    @honors ||= (work.oral_history_content&.interviewee_honor || []).sort_by(&:start_date)
  end

  # Hash where key is institution, value is array of jobs at that institution.
  #
  # Jobs within an institution are sorted by date.
  #
  # Institution  Keys in Hash should be inserted in order of FIRST date in that institution.
  def grouped_jobs
    @grouped_jobs ||= begin
      # groups will be an array of pairs, like [ [institution, [array]], [institution [array]], ...]
      groups  = (work.oral_history_content&.interviewee_job || []).group_by {|job| job.institution }.to_a

      groups.each do |institution, jobs|
        jobs.sort_by! {|job| job.start || 0 }
      end

      groups.sort_by! { |institution, jobs| jobs.first&.start || 0 }

      groups.to_h
    end
  end

  def birth_info
    @birth_info ||= formatted_date_and_place(oral_history_content&.interviewee_birth)
  end

  def death_info
    @death_info ||=  formatted_date_and_place(oral_history_content&.interviewee_death)
  end


  private

  # @param date_and_place [OralHistoryContent::DateAndPlace]
  def formatted_date_and_place(date_and_place)
    return nil if date_and_place.nil?

    date = FormatSimpleDate.new(date_and_place.date).display
    place = [date_and_place.city, date_and_place.state_name, date_and_place.province_name, date_and_place.country_name].compact.join(", ")

    [date, place].compact.join(" — ")
  end
end
