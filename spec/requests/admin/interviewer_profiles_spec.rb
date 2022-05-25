require 'rails_helper'

describe "interviewer profiles" do
  context "with a logged-in admin user", logged_in_user: :admin do
    let!(:interviewers) { [
      InterviewerProfile.new(name: "person one", profile: "bio one").tap{ |x| x.save! },
      InterviewerProfile.new(name: "person two", profile: "bio two").tap{ |x| x.save! }
      ]
    }
    
    it "shows the interviewer" do
      get(admin_interviewer_profiles_path)
      expect(response).to have_http_status(200)
      expect(response.body).to include(CGI::escapeHTML(interviewers.first.name))
      expect(response.body).to include(CGI::escapeHTML(interviewers.second.name))
    end

    it "can search for an interviewer" do
      get admin_interviewer_profiles_path(q: interviewers.first.name.upcase)
      expect(response).to have_http_status(200)
      expect(response.body).to include(CGI::escapeHTML(interviewers.first.name))
      expect(response.body).not_to include(CGI::escapeHTML(interviewers.second.name))
    end
  end
end
