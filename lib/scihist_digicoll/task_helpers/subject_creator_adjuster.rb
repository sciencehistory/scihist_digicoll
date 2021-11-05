module ScihistDigicoll
  module TaskHelpers

    # This is meant to be called by the rake task scihist:data_fixes:adjust_subjects_and_creators
    # which instantiates this lass *once*, then calls process_work(work) on each work in the collection.
    # process_work just updates the subjects and authors of a work according to @metadata_map.
    class SubjectCreatorAdjuster
      attr_accessor :metadata_map, :keys_to_check_for, :changes, :errors
      
      def initialize
        @changes = []
        @errors = []
        @metadata_map = {
          "Bredig, Georg, 1868-" => "Bredig, Georg, 1868-1944",
          "Caruso, David J."     => "Caruso, David J., (David Joseph), 1978-",
        }
        @keys_to_check_for = @metadata_map.keys
        raise ArgumentError, "Can't have nil values for @metadata_map" if @metadata_map.values.any?(&:nil?)
      end

      def change_if_necessary(value)
        @metadata_map.fetch(value, value)
      end

      def process_work(work)
        update_subject(work) unless (work.subject              & @keys_to_check_for).empty?
        update_creator(work) unless (work.creator.map(&:value) & @keys_to_check_for).empty?
      end

      # Update all subject headings according to @metadata_map.
      def update_subject(work)
        updated_subject = work.subject.map { |s| change_if_necessary(s) }
        if work.update({subject: updated_subject})
          @changes <<  [ work.friendlier_id, work.title, updated_subject ]
        else
          @errors << [ work.friendlier_id, work.title, work.subject, 'could not change subject']
        end
      end
      
      # Update all values of `creator`, regardless of category, according to @metadata_map.
      def update_creator(work)
        work.creator.each { |cr| cr.value = change_if_necessary(cr.value) }
        if work.save!
          @changes <<  [ work.friendlier_id, work.title, work.creator ]
        else
          @errors <<  [ work.friendlier_id, work.title, work.creator, 'could not change creator']
        end
      end

    end
  end
end