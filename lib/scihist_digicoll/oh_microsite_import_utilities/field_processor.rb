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
      @errors = []
      @works_updated = Set.new()
      progress_bar
    end

    def process()
      no_source = @mapper.no_source()
      @works.find_each do |w|
        if no_source.include? w.friendlier_id
          increment
          next
        end
        update_work(@field, w)
        increment
      end
    end

    def update_work(field, w)
      relevant_rows = select_rows(@rows, w)
      return if relevant_rows.empty?
      begin
        Updaters.send(field, w.oral_history_content, relevant_rows)
        w.oral_history_content.save!
      rescue StandardError => e
        @errors << "#{w.title} (#{w.friendlier_id}): error with #{field}:\n#{e.inspect}"
        return
      end
      @works_updated << w
    end

    def progress_bar
      # @progress_bar ||= ProgressBar.create( total: @works.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e", title: @field.ljust(15) )
    end

    def increment()
      return unless @progress_bar
      @progress_bar.increment
    end
  end
end