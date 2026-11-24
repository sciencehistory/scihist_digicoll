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
# Each finds or creates sample data if needed. OR, with an actual work you have in your dev db:
#
#    http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email?work_friendlier_id=q87u4qt
#
class OralHistoryDeliveryMailerPreview < ActionMailer::Preview
  CUSTOM_MESSAGE = "[[This is optional customized per-email instructions written by staff to patron, possibly including usage restrictions.]]"

  # optional ?work_friendlier_id=adf34aefadf, else sample mp3 work
  #
  # http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email?work_friendlier_id=adf34aefadf
  def oral_history_delivery_email
    return oral_history_delivery_email_mp3 if params[:work_friendlier_id].blank?

    work = Work.find_by_friendlier_id!(params[:work_friendlier_id])

    request = OralHistoryRequest.
      create_with(patron_name: "John Smith",
                  patron: sample_patron,
                  intended_use: "just cause").
      find_or_create_by(work: work)

    OralHistoryDeliveryMailer.
      with(request: request, custom_message: CUSTOM_MESSAGE).
      oral_history_delivery_email
  end

  # http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email_mp3
  def oral_history_delivery_email_mp3
    OralHistoryDeliveryMailer.
      with(request: oral_history_request(file_type: :mp3), custom_message: CUSTOM_MESSAGE).
      oral_history_delivery_email
  end

  # http://localhost:3000/rails/mailers/oral_history_delivery_mailer/oral_history_delivery_email_flac
  def oral_history_delivery_email_flac
    OralHistoryDeliveryMailer.
      with(request: oral_history_request(file_type: :flac), custom_message: CUSTOM_MESSAGE).
      oral_history_delivery_email
  end

  ## new style emails


  # http://localhost:3000/rails/mailers/oral_history_delivery_mailer/approved_with_session_link_email
  # http://localhost:3000/rails/mailers/oral_history_delivery_mailer/approved_with_session_link_email?request_id=134
  def approved_with_session_link_email
    OralHistoryDeliveryMailer.with(request: request_with_status("approved"), custom_message: CUSTOM_MESSAGE).
      approved_with_session_link_email
  end

  # http://localhost:3000/rails/mailers/oral_history_delivery_mailer/rejected_with_session_link_email
  # http://localhost:3000/rails/mailers/oral_history_delivery_mailer/rejected_with_session_link_email?request_id=137
  def rejected_with_session_link_email
    OralHistoryDeliveryMailer.with(request: request_with_status("rejected"), custom_message: CUSTOM_MESSAGE).
      rejected_with_session_link_email
  end



  protected

  # ?request_id param, else existing request with status, else new one on the sample mp3 work
  def request_with_status(status)
    return OralHistoryRequest.find(params[:request_id]) if params[:request_id].present?

    OralHistoryRequest.where(delivery_status: status).where.not(patron: nil).first ||
      OralHistoryRequest.create!(
        work: oral_history_request(file_type: :mp3).work,
        patron_name: "John Smith",
        patron: sample_patron,
        intended_use: "just cause",
        delivery_status: status
      )
  end

  def sample_patron
    Patron.create_or_find_by!(email: "smith@example.com") { |p| p.name = "Test Patron" }
  end

  def sample_work_title(file_type:)
    "Faked Sample OH Request work: #{file_type.to_s}"
  end

  # find or create a test request, we're hopefully in development here!
  def oral_history_request(file_type:)
    existing_sample = OralHistoryRequest.joins(:work).
                        where(work: { title: sample_work_title(file_type: file_type) }).first

    if params[:refresh] && existing_sample
      existing_sample.work.destroy!
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
      work = FactoryBot.create(:oral_history_work, :available_by_request_flac,
              title: sample_work_title(file_type: file_type),
              published: true)
    else
      raise ArgumentError, "don't know how to do file_type #{file_type}"
    end

    request = OralHistoryRequest.create!(
      work: work,
      patron_name: "John Smith",
      patron: sample_patron,
      intended_use: "just cause"
    )
  end
end
