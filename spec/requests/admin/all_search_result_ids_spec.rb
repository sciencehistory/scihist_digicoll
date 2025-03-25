require 'rails_helper'
describe AllSearchResultIdsController, type: :request, solr: true, queue_adapter: :test, indexable_callbacks: true, logged_in_user: true do

  #let!(:user) { FactoryBot.create(:admin_user, email: 'the_user@sciencehistory.org', password: "goatgoat") }


  let(:works_in_cart) {
    User.all.first.works_in_cart.count
  }

  let(:search_results) {
    controller.search_service.search_results
  }



  context "smoke test" do
    let!(:works) { [
      create(:work, title: "work_a"),
      create(:work, title: "work_b")
    ] }

    it "successfully adds works to the user's cart" do
      get all_search_result_ids_add_to_cart_path
      expect(response.code).to eq "302"
      expect(works_in_cart).to eq 2
    end
  end

  context "checking parameters" do


    let(:complex_query_with_facets) {
      {
        "search_field" => "all_fields",
        "f" => {
          "creator_facet"=>["Dow Chemical Company"],
          "department_facet"=>["Archives"],
          "format_facet"=>["Image"],
          "subject_facet"=>["Employees", "Industries"]
        },
        "q" => "Midland",
        "range" => {
            "year_facet_isim"=>{"begin"=>"1950", "end"=>"2023"}
        },
      }
    }

    let(:solr_params) {
      controller.search_service.search_results['responseHeader']['params']
    }

    it "controller params unchanged" do
      get all_search_result_ids_add_to_cart_path, params: complex_query_with_facets

      expect(response.code).to eq "302"

      incoming_params = controller.params.dup.permit!.to_h
      incoming_params.delete('action')
      incoming_params.delete('controller')
      expect(incoming_params).to eq complex_query_with_facets
    end

    it "makes the edits we want before contacting solr" do
      get all_search_result_ids_add_to_cart_path, params: complex_query_with_facets

      # should return exclusively IDs:
      expect(solr_params['fl']).to eq  "id"

      # should return ten million works, max:
      expect(solr_params['rows']).to eq "10000000"

      # all other solr params are preserved, so we know the IDS correspond exactly to the search results from the catalog controller:

      # search phrase
      expect(solr_params['q']).to eq "Midland"

      # fields:
      expect(solr_params['qf']).to eq "text1_tesim^1000 text2_tesim^500 text3_tesim^100 text4_tesim^50 description_text4_tesim^50 text_no_boost_tesim^10 friendlier_id_ssi id^10 searchable_fulltext_en^0.5 searchable_fulltext_de^0.5 searchable_fulltext_language_agnostic^0.5 admin_only_text_tesim admin_only_text_tesim"
      expect(solr_params['pf']).to eq "text1_tesim^1500 text2_tesim^1200 text3_tesim^600 text4_tesim^120 description_text4_tesim^120 text_no_boost_tesim^55 friendlier_id_ssi id^55 searchable_fulltext_en^12 searchable_fulltext_de^12 searchable_fulltext_language_agnostic^12"

      # facets:
      expect(solr_params['fq']).to eq   [
        "year_facet_isim:[1950 TO 2023]",
        "{!term f=subject_facet}Employees",
        "{!term f=subject_facet}Industries",
        "{!term f=creator_facet}Dow Chemical Company",
        "{!term f=format_facet}Image",
        "{!term f=department_facet}Archives"
       ]

      # default sort:
      expect(solr_params['sort']).to eq "score desc, date_created_dtsi desc"
    end
  end

end
