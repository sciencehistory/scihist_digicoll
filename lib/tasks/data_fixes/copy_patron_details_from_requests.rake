namespace :scihist do
  namespace :data_fixes do

    desc """
      Copy name and institution from each Patron's most recent OralHistoryRequest onto the Patron,
      where the Patron doesn't already have them.

      Also marks confirmed any Patron with an approved or automatic request, since they were
      emailed delivery links.
    """
    task :copy_patron_details_from_requests => :environment do
      progress_bar = ProgressBar.create(total: Patron.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Patron.find_each do |patron|
        progress_bar.increment

        latest_request = patron.oral_history_requests.order(created_at: :desc).first
        next unless latest_request

        patron.name = latest_request.legacy_patron_name if patron.name.blank?
        patron.institution = latest_request.legacy_patron_institution if patron.institution.blank?
        if patron.confirmed_at.blank? && patron.oral_history_requests.where(delivery_status: ["approved", "automatic"]).exists?
          patron.confirmed_at = Time.current
        end
        patron.save! if patron.changed?
      end
    end
  end
end
