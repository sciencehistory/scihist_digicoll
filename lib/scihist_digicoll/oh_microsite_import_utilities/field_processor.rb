# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata
module OhMicrositeImportUtilities
  class FieldProcessor
    attr_accessor :errors, :works_updated

    def initialize(field:, works:, mapper:, rows:)
      @debug_fields = [] # regular mode
      # @debug_fields = ['any'] # supress progress bar and fail fast
      # @debug_fields = ['birth_city'] #suppress progress bar, fail fast, and ignore all metadata except specified fields.
      @field, @works, @mapper, @rows = field, works, mapper, rows
      ghosts = @mapper.ghosts
      @rows.reject! { |arr| ghosts.include? arr['interview_entity_id'] }
      @errors = []
      @works_updated = Set.new
      progress_bar unless @debug_fields.present?
    end

    def process
      return if @debug_fields.present? &&
        @debug_fields != ['any'] &&
        !(@debug_fields.include? @field)
      no_source = @mapper.no_source
      @works.find_each do |w|
        if no_source.include? w.friendlier_id
          increment
          next
        end
        update_work(@field, w)
        increment
      end
    end

    def transformations
      transformed_fields = {
        'education' => 'school_name',
        'career'    => 'employer_name'
      }

      transformed_field = transformed_fields[@field]
      return unless transformed_field.present?

      transform_file_name = "#{transformed_field}_transforms.json"
      @transformations ||= JSON.parse(File.read("#{files_location}/#{transform_file_name}"))
    end

    def update_work(field, w)
      relevant_rows = select_rows(@rows, w)
      return if relevant_rows.empty?
      begin
        Updaters.send(field, w.oral_history_content, relevant_rows, transformations: transformations)
        w.oral_history_content.interviewee_biographies.each { |b| b.save! }
      rescue StandardError => e
        if @debug_fields.present?
          # debug mode: fail fast and provide accurate stacktrace
          raise e
          abort
        else
          # regular mode: list all errors for later debugging.
          @errors << "#{w.title} (#{w.friendlier_id}): error with #{field}:\n#{e.inspect}"
          return
        end
      end
      @works_updated << w
    end

    def progress_bar
      @progress_bar ||= ProgressBar.create( total: @works.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e", title: @field.ljust(15) )
    end

    def increment
      return unless @progress_bar
      @progress_bar.increment
    end
  end
end