require "rails_helper"

describe "Patron sign-in with emailed code", type: :request, queue_adapter: :inline do
  let(:patron) { create(:patron, :unconfirmed) }
  let(:return_to) { "/works/abc" }

  def code_from_email
    mail = ActionMailer::Base.deliveries.reverse.find { |m| m.to == [patron.email] }
    Nokogiri::HTML(mail.body.decoded).at_css("[data-sign-in-code]").text
  end

  def request_code
    post oral_history_session_path, params: { email: patron.email, return_to: return_to }
    expect(response).to redirect_to(code_oral_history_session_path(return_to: return_to))
  end

  it "shows code form, and correct code signs in, confirms, and returns" do
    request_code
    follow_redirect!
    expect(response.body).to include(patron.email)
    expect(Nokogiri::HTML(response.body).at_css("input[data-role=sign-in-code-input]")["autocomplete"]).to eq "one-time-code"

    post code_oral_history_session_path, params: { code: code_from_email, return_to: return_to }
    expect(response).to redirect_to(return_to)
    expect(patron.reload).to be_confirmed

    get patron_account_path
    expect(response).to have_http_status(200)
  end

  it "rejects wrong code" do
    request_code
    wrong = format("%06d", (code_from_email.to_i + 1) % 1_000_000)

    post code_oral_history_session_path, params: { code: wrong, return_to: return_to }
    expect(response).to redirect_to(code_oral_history_session_path(return_to: return_to))
    expect(flash[:auto_link_message]).to include("incorrect or has expired")

    get patron_account_path
    expect(response).not_to have_http_status(200)
  end

  it "rejects a code without the email in session" do
    code = patron.generate_sign_in_code!

    post code_oral_history_session_path, params: { code: code }
    expect(response).to redirect_to(code_oral_history_session_path)

    get code_oral_history_session_path
    expect(response).to redirect_to(new_oral_history_session_path)
  end

  it "rejects reused code" do
    request_code
    code = code_from_email
    post code_oral_history_session_path, params: { code: code }
    delete oral_history_session_path

    post code_oral_history_session_path, params: { code: code }
    expect(response).to redirect_to(code_oral_history_session_path)
  end

  describe "from registration modal" do
    let(:work) { create(:oral_history_work, :available_by_request, availability_mode: :automatic_request) }

    it "renders code form in modal" do
      post register_oral_history_path,
        params: { work_friendlier_id: work.friendlier_id, patron: { email: patron.email, name: "Pat" } },
        xhr: true

      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css("input[data-role=sign-in-code-input]")).to be_present
      expect(doc.at_css("input[name=return_to]")["value"]).to eq work_path(work.friendlier_id)
    end
  end
end
