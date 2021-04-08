# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata
module OhMicrositeImportUtilities
  class FieldProcessor
    attr_accessor :errors, :works_updated, :field, :destination_records, :mapper, :results

    def initialize(args)
      @field                  = args[:field]
      @works                  = args[:works]
      @mapper                 = args[:mapper]
      @results                = args[:results]
      @ghosts               ||= args[:mapper].ghosts()
      @no_source            ||= args[:mapper].no_source()
      @results.reject!{|arr| @ghosts.include? arr['interview_entity_id'] }
    end

    def increment()
      return unless @progress_bar
      @progress_bar.increment
    end

    def process()
      @errors = []
      @works_updated = Set.new()
      @progress_bar = ProgressBar.create( total: @works.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e", title: @field.ljust(15) )
      @works.find_each do |w|
        if @no_source.include? w.friendlier_id
          increment; next
        end
        relevant_rows = select_rows(results, w)
        update_errors = work_update_errors(field, w, relevant_rows)
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
  end
end