require 'rails_helper'

RSpec.describe "Logins", type: :system do
  let(:password) { "test_password" }
  let!(:user) { FactoryBot.create(:user, password: password) }

  it "can login" do
    visit new_user_session_path

    fill_in "Email", with: user.email
    fill_in "Password", with: user.password
    click_on "Log in"

    expect(page).to have_text("Signed in successfully")
  end

  context "locked out user" do
    it "can't log in" do
      user.update(locked_out: true)

      visit new_user_session_path

      fill_in "Email", with: user.email
      fill_in "Password", with: user.password
      click_on "Log in"

      expect(page).to have_text("your account is disabled")
    end

    it "kicked out if already logged in" do
      sign_in user
      user.update(locked_out: true)

      visit admin_works_path
      expect(page).to have_text("your account is disabled")
    end
  end

  context "global lock-out" do
    it "can't log in" do
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)
      visit new_user_session_path

      fill_in "Email", with: user.email
      fill_in "Password", with: user.password
      click_on "Log in"

      expect(page).to have_text("logins are temporarily disabled")
    end

    it "kicked out if already logged in" do
      sign_in user
      visit admin_works_path
      expect(page).to have_text("Works")

      allow(ScihistDigicoll::Env).to receive(:lookup).with(:logins_disabled).and_return(true)

      visit admin_works_path
      expect(page).to have_text("logins are temporarily disabled")
    end
  end

end
