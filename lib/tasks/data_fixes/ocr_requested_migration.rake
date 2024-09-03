namespace :scihist do
  namespace :data_fixes do

    desc """
      move ocr_requested boolean attr_json to value in new text_extraction_mode
    """
    task :ocr_requested_migration => :environment do
      # has key
      scope = Work.where("json_attributes ? 'ocr_requested'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          value = work.json_attributes.delete('ocr_requested')
          if ActiveModel::Type::Boolean.new.cast(value)
            work.text_extraction_mode = "ocr"
          end
          work.save!
          progress_bar.increment
        end
      end
    end
  end
end
