class DigitizationQueueMailer < ApplicationMailer
  # @example DigitizationQueueMailer.with(digitization_queue_item: dig_queue_item).new_item_email.deliver_later
  def new_item_email
    @digitization_queue_item = params[:digitization_queue_item]

    subject = "New Digitization Queue Item in #{@digitization_queue_item.collecting_area.humanize}: #{@digitization_queue_item.title}"
    unless ScihistDigicoll::Env.production?
      subject = "[#{ScihistDigicoll::Env.lookup(:service_level)}] #{subject}"
    end

    mail(to: ScihistDigicoll::Env.lookup!(:digitization_queue_alerts_email_address),
      subject: subject
    )
  end
end
