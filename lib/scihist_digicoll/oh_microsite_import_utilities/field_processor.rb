# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata
module OhMicrositeImportUtilities
  class FieldProcessor
    attr_accessor :errors, :works_updated

    def initialize(field:, works:, mapper:, rows:)
      @field, @works, @mapper, @rows = field, works, mapper, rows
      ghosts = @mapper.ghosts()
      @rows.reject! { |arr| ghosts.include? arr['interview_entity_id'] }
    end

    def process()
      @errors = []
      @works_updated = Set.new()
      @progress_bar = ProgressBar.create( total: @works.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e", title: @field.ljust(15) )
      no_source = @mapper.no_source()
      @works.find_each do |w|
        if no_source.include? w.friendlier_id
          increment; next
        end
        relevant_rows = select_rows(@rows, w)
        update_errors = work_update_errors(@field, w, relevant_rows)
        if update_errors.present?
          @errors << update_errors
        else
          @works_updated << w
        end
        increment
      end
    end

    def work_update_errors(field, w, relevant_rows)
      return nil if relevant_rows.count == 0
      begin
        Updaters.send(field, w.oral_history_content, relevant_rows)
        w.oral_history_content.save!
      rescue StandardError => e
        return "#{w.title} (#{w.friendlier_id}): error with #{field}:\n#{e.inspect}"
      end
      return nil
    end

    def increment()
      return unless @progress_bar
      @progress_bar.increment
    end
  end
end