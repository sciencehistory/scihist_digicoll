namespace :scihist do
  namespace :data_fixes do

    desc """
      Move Admin::OralHistoryAccessRequest#patron_email to associated Admin::OralHistoryRequesterEmail instead
    """
    task :migrate_oh_request_email => :environment do
      progress_bar = ProgressBar.create(total: Admin::OralHistoryAccessRequest.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)


      Admin::OralHistoryAccessRequest.find_each do |request|
        progress_bar.increment

        next if request.oral_history_requester_email.present?

        if request.patron_email.present?
          request.oral_history_requester_email = Admin::OralHistoryRequesterEmail.find_or_create_by(email: request.patron_email)
          request.save!

          # double-check before we remove data
          request.reload
          unless request.patron_email == request.oral_history_requester_email.email
            raise "data missing for Admin::OralHistoryAccessRequest #{request.id}, #{request.patron_email}"
          end

          request.save!
        end
      end
    end
  end
end
