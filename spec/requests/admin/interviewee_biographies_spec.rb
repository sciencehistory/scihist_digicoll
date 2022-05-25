require 'rails_helper'

describe "interviewee biographies" do
  context "with a logged-in admin user", logged_in_user: :admin do
    let!(:interviewees) { [
        create(:interviewee_biography, name: "D'Andrade"),
        create(:interviewee_biography, name: "Johnson")
      ]
    }

    it "shows the interviewees" do
      get admin_interviewee_biographies_path
      expect(response).to have_http_status(200)
      expect(response.body).to include(CGI::escapeHTML(interviewees.first.name))
      expect(response.body).to include(CGI::escapeHTML(interviewees.second.name))
    end

    it "can search for an interviewee" do
      get admin_interviewee_biographies_path(q: interviewees.first.name.upcase)
      expect(response).to have_http_status(200)
      expect(response.body).to include(CGI::escapeHTML(interviewees.first.name))
      expect(response.body).not_to include(CGI::escapeHTML(interviewees.second.name))
    end
  end
end