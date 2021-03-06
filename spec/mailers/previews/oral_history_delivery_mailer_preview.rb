# even though we are in development, we'll use FactoryBot to create
# some sample data to preview
require 'factory_bot_rails'

# For ActionMailer preview functionality, in dev you can go to eg
# http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email
#
class OralHistoryDeliveryMailerPreview < ActionMailer::Preview
  SAMPLE_WORK_TITLE = "Sample OH Request work"

  def oral_history_delivery_email
    OralHistoryDeliveryMailer.
      with(request: oral_history_request, custom_message: "[[This is optional customized per-email instructions written by staff to patron, possibly including usage restrictions.]]").
      oral_history_delivery_email
  end

  protected

  # find or create a test request, we're hopefully in development here!
  def oral_history_request
    existing_sample = Admin::OralHistoryAccessRequest.joins(:work).where(work: { title: SAMPLE_WORK_TITLE }).first
    existing_sample || create_sample_request
  end

  def create_sample_request
    work = FactoryBot.create(:oral_history_work, :available_by_request, title: SAMPLE_WORK_TITLE, published: true)

    request = Admin::OralHistoryAccessRequest.create!(
      work: work,
      patron_name: "John Smith",
      patron_email: "smith@example.com",
      intended_use: "just cause"
    )
  end
end
