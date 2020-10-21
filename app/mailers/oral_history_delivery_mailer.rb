class OralHistoryDeliveryMailer < ApplicationMailer

  def oral_history_delivery_email
    raise ArgumentError.new("Required params[:request] missing") unless request.present?
    #@request = params[:request]

    raise ArgumentError.new("Required patron email missing") unless request.patron_email.present?

    # created_at:
    #            patron_name: "Patron #{i}",
    #            patron_email: "patron@institution_#{i}.com",
    #            patron_institution: "Institution #{i}",
    #            intended_use: "I will write #{i} books.",
    #            work: work

    from_address = ScihistDigicoll::Env.lookup(:no_reply_email_address)

    unless from_address.present?
      raise RuntimeError, 'Cannot send fixity error email; specify at least a "from" address'
    end

    mail(
      from:         from_address,
      to:           request.patron_email,
      subject:      subject,
      content_type: "text/html",
    )
  end

  def request
    @request ||= params[:request]
  end

  def created_at
    request.created_at
  end

  def patron_name
    request.patron_name
  end

  def work
    request.work
  end

  def assets
    work.members.select {|x| x.is_a? Asset}
  end

  def subject
    "Science History Institute: files from #{work.title}"
  end

  def hostname
    ScihistDigicoll::Env.lookup!(:app_url_base)
  end

  def work_url
    @work_url ||= "#{hostname}#{Rails.application.routes.url_helpers.work_path(work.friendlier_id)}"
  end

  def work_link
    "<a href=\"#{work_url}\">#{work.title}</a>".html_safe
  end
end