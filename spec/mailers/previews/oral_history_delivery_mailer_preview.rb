# even though we are in development, we'll use FactoryBot to create
# some sample data to preview
require 'factory_bot_rails'


class OralHistoryDeliveryMailerPreview < ActionMailer::Preview
  SAMPLE_WORK_TITLE = "Sample OH Request work"

  def oral_history_delivery_email
    OralHistoryDeliveryMailer.
      with(request: oral_history_request).
      oral_history_delivery_email
  end

  protected

  # find or create a test request, we're hopefully in development here!
  def oral_history_request
    existing_sample = Admin::OralHistoryAccessRequest.joins(:work).where(work: { title: SAMPLE_WORK_TITLE }).first
    existing_sample || create_sample_request
  end

  def create_sample_request
    preview_pdf = FactoryBot.create(:asset_with_faked_file, :pdf, published: true)
    protected_pdf = FactoryBot.create(:asset_with_faked_file, :pdf, title: "audio_recording.mp3", published: false, oh_available_by_request: true)
    protected_mp3 =  FactoryBot.create(:asset_with_faked_file, :mp3, title: "transcript.pdf", published: false, oh_available_by_request: true)

    work = FactoryBot.create(:oral_history_work, title: SAMPLE_WORK_TITLE, published: true).tap do |work|
      work.members << preview_pdf
      work.members << protected_pdf
      work.members << protected_mp3

      work.representative =  preview_pdf
      work.save!

      work.oral_history_content!.update(available_by_request_mode: :manual_review)
    end

    request = Admin::OralHistoryAccessRequest.create!(
      work: work,
      patron_name: "John Smith",
      patron_email: "smith@example.com",
      intended_use: "just cause"
    )
  end
end
