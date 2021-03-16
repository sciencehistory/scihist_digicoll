require 'rails_helper'

RSpec.describe Admin::WorksController, :logged_in_user, type: :controller, queue_adapter: :test do

  context "with a logged-in admin user", logged_in_user: :admin do
    let(:work) { create(:work, :published, published: false) }

    context "oral history bio" do
      let(:work) { create(:public_work) }

      it "sanitizes params and deletes birth and death if empty" do
        put :submit_oh_biography, params: {
          "oral_history_content"=> {
            "interviewee_birth_attributes"=>{"date"=>"", "city"=>"", "state"=>"", "province"=>"", "country"=>""},

            "interviewee_death_attributes"=>{"date"=>"2014-10", "city"=>"Silver Spring", "state"=>"", "province"=>"NL", "country"=>"CA"},

            "interviewee_school_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"date"=>"1984", "institution"=>"Catholic Church", "degree"=>"PhD", "discipline"=>"Basketweaving"}},

            "interviewee_job_attributes"=>
              {"_kithe_placeholder"=>{"_destroy"=>"1"},
               "0"=>{"start"=>"1960", "end"=>"1962", "institution"=>"New Zealand Dairy Goat Breeders Association", "role"=>"Lead Goatherd"},
               "1"=>{"start"=>"1909", "end"=>"2034", "institution"=>"Chicago Bears (Football team)", "role"=>"Coach"}},

            "interviewee_honor_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"start_date"=>"1923", "end_date"=>"1925", "honor"=>"Nobel Prize A"},
              "1"=>{"start_date"=>"", "end_date" => "", "honor"=>""}, # should be deleted
              "2"=>{"start_date"=>"1924", "honor"=>"Nobel Prize B"},
              "3"=>{"start_date"=>nil, "honor"=>nil}, # delete this one too please
              "4"=>{"start_date"=>"1925", "honor"=>"Nobel Prize C"},
            }},

            "id"=> work.friendlier_id
          }
        expect(response.status).to redirect_to(admin_work_path(work, :anchor => "nav-oral-histories"))
        expect(work.oral_history_content.interviewee_birth).to be_nil
        expect(work.oral_history_content.interviewee_honor.map{|h| h.attributes}).to eq [
          {"start_date"=>"1923", "end_date" => "1925", "honor"=>"Nobel Prize A"},
          {"start_date"=>"1924", "honor"=>"Nobel Prize B"},
          {"start_date"=>"1925", "honor"=>"Nobel Prize C"}
        ]
      end

      it "does not throw an error when a date is incorrect" do
        put :submit_oh_biography, params: {
          "oral_history_content"=>{
            "interviewee_birth_attributes"=>{"date"=>"abc", "city"=>"", "state"=>"", "province"=>"", "country"=>""},
            "interviewee_death_attributes"=>{"date"=>"", "city"=>"", "state"=>"", "province"=>"", "country"=>""},
            "interviewee_school_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"}},
            "interviewee_job_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"}},
            "interviewee_honor_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"}}
          },
          "id"=> work.friendlier_id
        }
        expect(response.status).to eq(200)
      end


      it "does not throw an error when death or birth info is missing from the params" do
        put :submit_oh_biography, params: {
          "oral_history_content"=>{
            "interviewee_birth_attributes"=>{"date"=>"bad date", "city"=>"", "state"=>"", "province"=>"", "country"=>""},
            "interviewee_school_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"date"=>"", "institution"=>"", "degree"=>"", "discipline"=>""}
            },
            "interviewee_job_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"start"=>"", "end"=>"", "institution"=>"", "role"=>""}
            },
            "interviewee_honor_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"start_date"=>"", "honor"=>""}
            }
          },
          "id"=> work.friendlier_id
        }
        expect(response.status).to eq(200)
      end
    end
  end
end
