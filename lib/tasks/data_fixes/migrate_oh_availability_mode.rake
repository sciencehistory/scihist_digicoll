namespace :scihist do
  namespace :data_fixes do
    desc """
    Copy data from old OralHistoryContent#available_by_request_mode to new #availability_mode
    """
    task :migrate_oh_availability_mode => :environment do
      progress_bar = ProgressBar.create(total: OralHistoryContent.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      counts = Hash.new { 0 }

      # The trick is that old "off" could mean new "direct" or "embargoed" -- this confusion
      # is in fact why we are migrating to new metadata model here.
      #
      # if work is published, available_by_request_mode is off AND there are NO published
      # assets, we consider "embargoed". Otherwise "direct"
      #
      # Select * to get around that we may be ActiveRecord ignoring the old field by default.


      OralHistoryContent.includes(:work => :members).select("oral_history_content.*").find_each(batch_size: 10) do |oc|
        if oc.available_by_request_mode == 'automatic'
          oc.availability_mode = "automatic_request"
          counts["automatic_request"] += 1

        elsif oc.available_by_request_mode == "manual_review"
          oc.availability_mode = "reviewed_request"
          counts["reviewed_request"] += 1

        elsif oc.available_by_request_mode == "off" && oc.work.published? && !oc.work.members.find { |a| a.published? }
          oc.availability_mode = "embargoed"
          counts["embargoed"] += 1

        else
          oc.availability_mode = "direct"
          counts["direct"] += 1
        end

        oc.save!

        GC.start
        progress_bar.increment
      end

      puts "\nSync'd availability_mode: #{counts}"
    end
  end
end
