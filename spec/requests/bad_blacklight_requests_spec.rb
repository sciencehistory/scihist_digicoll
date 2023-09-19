# Some bad query params for Blacklight results in an uncaught exception and 500 error.
#
# We want to catch them nicely and avoid the 500 error in our logs. Sometimes we
# try to correct, but mostly we've moved on to just responding HTTP 400, Bad Request.
#
# This request spec is ones that we just return 400 for.
# See even more at catalog_controller_spec.rb "malformed URL params", the
# ones that are just returning 400 would be easier to spec here.

require 'rails_helper'

describe CatalogController do
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

  # This was another one used as some kind of attempt at injection attack, which
  # was causing a Solr 4xx
  describe "weird attack in range value" do
    it "responds with 400" do
      get "/catalog?range%5Byear_facet_isim%5D%5Bbegin%5D=1989%27,(;))%23-%20--&range%5Byear_facet_isim%5D%5Bend%5D=1989%27,(;))%23-%20--"
      expect(response.code).to eq("400")
    end

    describe "on a collection search" do
      let(:collection) { create(:collection) }

      it "responds with 400" do
        get "/collections/#{collection.friendlier_id}/facet?id=subject_facet&range[year_facet_isim][end]=1894%27[0]"
        expect(response.code).to eq("400")
      end
    end
  end

  # Missing facet ID, e.g.
  #    /collections/gt54kn818/facet
  # https://app.honeybadger.io/projects/58989/faults/80390739
  describe "missing facet id" do
    let(:collection) { create(:collection) }
    it "collections page search responds with 400" do
      url = "/collections/#{collection.friendlier_id}/facet"
      expect { get url }.
        to raise_error(an_instance_of(ActionController::RoutingError).
        and having_attributes(message: "Not Found"))
    end
    it "featured topic search responds with 400" do
      fake_definition =  {
          test_featured_topic: {
          title: "Instruments & Innovation",
          genre: ["Scientific apparatus and instruments", "Lithographs"],
          subject: ["Artillery", "Machinery", "Chemical apparatus"],
          description: "Fireballs!",
          description_html: "<em>Fireballs!</em>"
        }
      }
      allow(FeaturedTopic).to receive(:definitions).and_return(fake_definition)
      expect(FeaturedTopic.from_slug(:test_featured_topic)).to be_a FeaturedTopic
      url = "/focus/test_featured_topic/facet"
      expect { get url}.
        to raise_error(an_instance_of(ActionController::RoutingError).
        and having_attributes(message: "Not Found"))
    end
  end

  describe "attempt to inject in page param" do
    it "responds with a 400" do
      get "/catalog?page=21111111111111%22%20"
      expect(response.code).to eq "400"
      expect(response.body).to match(/illegal page query parameter/)
    end
  end

  describe "attempt to inject in page param" do
    it "responds with a 400" do
      get "/catalog?page=1&q[]=1"
      expect(response.code).to eq "400"
      expect(response.body).to match(/illegal q query parameter/)
    end
  end
end
