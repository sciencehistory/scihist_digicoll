require 'rails_helper'

# We coudln't manage to test our actual custom error handling in a request or system test,
# but we can just test the controller that we set up as our custom error handler.
describe ErrorsController do
  render_views

  it "404" do
    get :not_found

    expect(response.status).to eq 404
    expect(response.body).to match(/Sorry, that page doesn't exist/)
  end

  it "500" do
    get :internal_error

    expect(response.status).to eq 500
    expect(response.body).to match /We're sorry. A software error occurred./

    # include custom honeybadger magic comment, that honeybadger gem
    # will replace with an error feedback form when used in real errors.
    expect(response.body).to match /<!-- HONEYBADGER FEEDBACK -->/
  end

  it "422" do
    get :unacceptable
    expect(response.status).to eq 422
  end
end
