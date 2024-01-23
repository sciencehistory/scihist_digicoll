namespace :scihist do
  namespace :data_fixes do

    desc """
      Move OralHistoryRequest#patron_email to associated OralHistoryRequester instead
    """
    task :migrate_oh_request_email => :environment do
      progress_bar = ProgressBar.create(total: OralHistoryRequest.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)


      OralHistoryRequest.find_each do |request|
        progress_bar.increment

        next if request.oral_history_requester.present?

        if request.patron_email.present?
          request.oral_history_requester = OralHistoryRequester.find_or_create_by(email: request.patron_email)
          request.save!

          # double-check before we remove data
          request.reload
          unless request.patron_email == request.oral_history_requester.email
            raise "data missing for OralHistoryRequest #{request.id}, #{request.patron_email}"
          end

          request.save!
        end
      end
    end
  end
end
