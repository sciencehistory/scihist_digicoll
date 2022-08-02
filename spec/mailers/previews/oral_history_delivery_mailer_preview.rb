# even though we are in development, we'll use FactoryBot to create
# some sample data to preview
require 'factory_bot_rails'

# For ActionMailer preview functionality, in dev you can go to eg
# http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email
#
class OralHistoryDeliveryMailerPreview < ActionMailer::Preview
  CUSTOM_MESSAGE = "[[This is optional customized per-email instructions written by staff to patron, possibly including usage restrictions.]]"

  def oral_history_delivery_email_mp3
    OralHistoryDeliveryMailer.
      with(request: oral_history_request(file_type: :mp3), custom_message: CUSTOM_MESSAGE).
      oral_history_delivery_email
  end

  def oral_history_delivery_email_flac
    OralHistoryDeliveryMailer.
      with(request: oral_history_request(file_type: :flac), custom_message: CUSTOM_MESSAGE).
      oral_history_delivery_email
  end


  protected

  def sample_work_title(file_type:)
    "Faked Sample OH Request work: #{file_type.to_s}"
  end

  # find or create a test request, we're hopefully in development here!
  def oral_history_request(file_type:)
    existing_sample = Admin::OralHistoryAccessRequest.joins(:work).
                        where(work: { title: sample_work_title(file_type: file_type) }).first
    existing_sample || create_sample_request(file_type: file_type)
  end


  def create_sample_request(file_type:)
    work = FactoryBot.create(:oral_history_work, :available_by_request,
              title: sample_work_title(file_type: file_type),
              audio_asset_factory: file_type,
              published: true)

    request = Admin::OralHistoryAccessRequest.create!(
      work: work,
      patron_name: "John Smith",
      patron_email: "smith@example.com",
      intended_use: "just cause"
    )
  end
end
