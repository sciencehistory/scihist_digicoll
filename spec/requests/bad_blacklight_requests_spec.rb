# Some bad query params for Blacklight results in an uncaught exception and 500 error.
#
# We want to catch them nicely and avoid the 500 error in our logs. Sometimes we
# try to correct, but mostly we've moved on to just responding HTTP 400, Bad Request.
#
# This request spec is ones that we just return 400 for.
# See even more at catalog_controller_spec.rb "malformed URL params", the
# ones that are just returning 400 would be easier to spec here.

require 'rails_helper'

describe CatalogController, solr: true do
  # https://app.honeybadger.io/projects/58989/faults/78909879/01F4Q6ZN3KVBPZ4BCG4Y36KJE5?page=0#notice-summary
  describe "facet params that aren't expected strings" do
    it "responds with 400" do
      get "/catalog?f%5Bdepartment_facet%5D%5B%5D%5B%3DLibrary%26q%3D%5D="
      expect(response.code).to eq("400")
    end
  end


  # escaped newline in range value, eg
  #    range%5Byear_facet_isim%5D%5Bbegin%5D=1588%0A
  # https://app.honeybadger.io/projects/58989/faults/79191107
  describe "newline in range facet" do
    it "responds with 400" do
      get "/catalog?range%5Byear_facet_isim%5D%5Bbegin%5D=1588%0A&range%5Byear_facet_isim%5D%5Bend%5D=2020%0A"
      expect(response.code).to eq("400")
    end
  end
end
