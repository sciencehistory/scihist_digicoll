namespace :scihist do
  namespace :data_fixes do
    desc """
    Migrate dig queue item statuses. See
    bundle exec rake scihist:data_fixes:edit_digitization_queue_item_statuses
    """
    task :edit_digitization_queue_item_statuses => :environment do
      mapping = {
        post_production_completed:     'image_export_completed',
        batch_metadata_completed:      'metadata_in_progress',
        individual_metadata_completed: 'metadata_in_progress',
        awaiting_dig_on_cart:          'awaiting_digitization',
        re_pull_object:                nil,
      }
      Admin::DigitizationQueueItem.transaction do
        Admin::DigitizationQueueItem.find_each do |item|
          if mapping.keys.include? item.status.to_sym
            new_status = mapping[item.status.to_sym]
            abort "ERROR: don't know how to migrate this status.\n" if new_status.nil?
            pp "Changing ##{item.id} from #{item.status} to #{new_status}"
            item.update!({status: new_status})
          end
          abort "ERROR: item #{item.id} isn't valid.\n" unless item.valid?
        end
      end
    end
  end
end
