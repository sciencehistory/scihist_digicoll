namespace :scihist do
  namespace :data_fixes do

    desc """
      Remove data from #exhibitions attribute, by directly editing json_attributes hash
    """
    task :remove_exhibition_attribute_data => :environment do
      # note we operate directly on json_attributes hash, so this task can be
      # run even after we remove "exhibition" attribute

      scope = Work.where("json_attributes -> 'exhibition' is not null")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          work.json_attributes.delete("exhibition")
          work.save!

          progress_bar.increment
        end
      end
    end
  end
end
