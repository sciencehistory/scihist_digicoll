# even though we are in development, we'll use FactoryBot to create
# some sample data to preview
require 'factory_bot_rails'

# For ActionMailer preview functionality, in dev you can go to eg
#
#     http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email_flac
#
# or
#     .../oral_history_delivery_email_mp3
#
# OR, with an actual work you have in your dev db:
#
#    http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email?work_friendlier_id=q87u4qt
#
class OralHistoryDeliveryMailerPreview < ActionMailer::Preview
  CUSTOM_MESSAGE = "[[This is optional customized per-email instructions written by staff to patron, possibly including usage restrictions.]]"

  # requires eg ?work_friendlier_id=adf34aefadf
  def oral_history_delivery_email
    work = Work.find_by_friendlier_id!(params[:work_friendlier_id])

    request = Admin::OralHistoryAccessRequest.
      create_with(patron_name: "John Smith",
                  patron_email: "smith@example.com",
                  intended_use: "just cause").
      find_or_create_by(work: work)

    OralHistoryDeliveryMailer.
      with(request: request, custom_message: CUSTOM_MESSAGE).
      oral_history_delivery_email
  end

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

    if params[:refresh] && existing_sample
      existing_sample.destroy!
      existing_sample = nil
    end

    existing_sample || create_sample_request(file_type: file_type)
  end


  def create_sample_request(file_type:)
    if file_type == :mp3
      work = FactoryBot.create(:oral_history_work, :available_by_request,
              title: sample_work_title(file_type: file_type),
              published: true)
    elsif file_type == :flac
      work = FactoryBot.create(:oral_history_work, :available_by_request,
              title: sample_work_title(file_type: file_type),
              members: [
                FactoryBot.build(:asset_with_faked_file, :pdf, published: true, title: 'Front matter'),
                FactoryBot.build(:asset_with_faked_file, :flac,
                  title: "smith_j_0001_1_1.flac",
                  faked_filename: "smith_j_0001_1_1.flac",
                  faked_size: 190.4.megabytes,
                  published: false,
                  oh_available_by_request: true,
                  faked_derivatives: {
                    m4a: FactoryBot.create(:stored_uploaded_file,
                                            file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a").to_s),
                                            size: 12.4.megabytes,
                                            content_type: "audio/mp4")
                  }
                ),
                FactoryBot.build(:asset_with_faked_file, :pdf, title: "transcript.pdf", published: false, oh_available_by_request: true)
              ],
              published: true)
    else
      raise ArgumentError, "don't know how to do file_type #{file_type}"
    end

    request = Admin::OralHistoryAccessRequest.create!(
      work: work,
      patron_name: "John Smith",
      patron_email: "smith@example.com",
      intended_use: "just cause"
    )
  end
end
