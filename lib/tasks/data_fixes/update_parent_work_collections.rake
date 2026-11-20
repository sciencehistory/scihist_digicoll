namespace :scihist do
  namespace :data_fixes do

    desc """
      Update parent works so any collection on a child should also be set to be on parent
    """
    task :update_parent_work_collections => :environment do
      parent_works = Work.where(id: Work.where.not(parent_id: nil).select(:parent_id)).for_batch_indexing.strict_loading

      progress_bar = ProgressBar.create(total: parent_works.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        parent_works.find_each(batch_size: 10) do |parent_work|
          child_collection_ids = parent_work.members.collect(&:contained_by_ids).flatten

          extras = (child_collection_ids - parent_work.contained_by_ids)
          if extras.any?
            progress_bar.log "Work #{parent_work.friendlier_id} needs some Collection id's from children: #{extras.join(',')}"
            parent_work.contained_by_ids = (parent_work.contained_by_ids + extras).uniq
            parent_work.save!
          end
          progress_bar.increment
        end
      end
    end
  end
end

