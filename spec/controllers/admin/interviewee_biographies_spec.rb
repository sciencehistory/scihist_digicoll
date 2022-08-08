require 'rails_helper'

RSpec.describe Admin::IntervieweeBiographiesController, :logged_in_user, type: :controller, solr: true, queue_adapter: :test do

  context "with a logged-in admin user", logged_in_user: :admin do

    context "create" do
      it "creates and sanitizes params" do
        post :create, params: {
          "interviewee_biography"=> {
            "name" => "John Smith",
            "birth_attributes"=>{"date"=>"", "city"=>"", "state"=>"", "province"=>"", "country"=>""},

            "death_attributes"=>{"date"=>"2014-10", "city"=>"Silver Spring", "state"=>"", "province"=>"NL", "country"=>"CA"},

            "school_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"date"=>"1984", "institution"=>"Catholic Church", "degree"=>"PhD", "discipline"=>"Basketweaving"}},

            "job_attributes"=>
              {"_kithe_placeholder"=>{"_destroy"=>"1"},
               "0"=>{"start"=>"1960", "end"=>"1962", "institution"=>"New Zealand Dairy Goat Breeders Association", "role"=>"Lead Goatherd"},
               "1"=>{"start"=>"1909", "end"=>"2034", "institution"=>"Chicago Bears (Football team)", "role"=>"Coach"}},

            "honor_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"start_date"=>"1923", "end_date"=>"1925", "honor"=>"Nobel Prize A"},
              "1"=>{"start_date"=>"", "end_date" => "", "honor"=>""}, # should be deleted
              "2"=>{"start_date"=>"1924", "honor"=>"Nobel Prize B"},
              "3"=>{"start_date"=>nil, "honor"=>nil}, # delete this one too please
              "4"=>{"start_date"=>"1925", "honor"=>"Nobel Prize C"},
            }
          }
        }

        expect(response.status).to redirect_to(admin_interviewee_biographies_path)

        biography = IntervieweeBiography.last

        expect(biography.death.date).to eq("2014-10")

        expect(biography.job.map(&:attributes)).to eq [
          {"start"=>"1960", "end"=>"1962", "institution"=>"New Zealand Dairy Goat Breeders Association", "role"=>"Lead Goatherd"},
          {"start"=>"1909", "end"=>"2034", "institution"=>"Chicago Bears (Football team)", "role"=>"Coach"}
        ]

        expect(biography.honor.map(&:attributes)).to eq [
          {"start_date"=>"1923", "end_date" => "1925", "honor"=>"Nobel Prize A"},
          {"start_date"=>"1924", "honor"=>"Nobel Prize B"},
          {"start_date"=>"1925", "honor"=>"Nobel Prize C"}
        ]
      end

      it "display error when the date is incorrect" do
        post :create, params: {
          "interviewee_biography"=>{
            "name" => "John Smith",
            "birth_attributes"=>{"date"=>"abc", "city"=>"", "state"=>"", "province"=>"", "country"=>""},
            "death_attributes"=>{"date"=>"", "city"=>"", "state"=>"", "province"=>"", "country"=>""},
            "school_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"}},
            "job_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"}},
            "honor_attributes"=>{"_kithe_placeholder"=>{"_destroy"=>"1"}}
          }
        }
        expect(response.status).to eq(200)
      end

      it "display error when death or birth info is missing from the params" do
        post :create, params: {
          "interviewee_biography"=>{
            "name" => "John Smith",
            "birth_attributes"=>{"date"=>"bad date", "city"=>"", "state"=>"", "province"=>"", "country"=>""},
            "school_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"date"=>"", "institution"=>"", "degree"=>"", "discipline"=>""}
            },
            "job_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"start"=>"", "end"=>"", "institution"=>"", "role"=>""}
            },
            "honor_attributes"=>{
              "_kithe_placeholder"=>{"_destroy"=>"1"},
              "0"=>{"start_date"=>"", "honor"=>""}
            }
          }
        }
        expect(response.status).to eq(200)
      end
    end

    context "#update" do
      let(:work) { create(:oral_history_work) }
      let(:interviewee_biography) { work.oral_history_content.interviewee_biographies.first }

      it "automatically triggeres a reindex of attached works" do
        # cheesy hacky way to test this...
        expect_any_instance_of(Work).to receive(:update_index)

        patch :update, params: {
          "id" => interviewee_biography.id,
          "interviewee_biography" =>
            { "birth_attributes"=>{"date"=>"1900", "city"=>"", "state"=>"", "province"=>"", "country"=>""} }
        }
      end

      it "can delete birth dates" do
        patch :update, params: {
          "id" => interviewee_biography.id,
          "interviewee_biography" =>
            { "birth_attributes"=>{"date"=>"", "city"=>"", "state"=>"", "province"=>"", "country"=>""} }
        }
        birth = interviewee_biography.reload.birth
        expect(birth.date).to eq("")
        expect(birth.city).to eq("")
        expect(birth.state).to eq("")
        expect(birth.province).to eq("")
        expect(birth.country).to eq("")
      end

      it "can delete death dates" do
        patch :update, params: {
          "id" => interviewee_biography.id,
          "interviewee_biography" =>
            { "death_attributes"=>{"date"=>"", "city"=>"", "state"=>"", "province"=>"", "country"=>""} }
        }
        death = interviewee_biography.reload.death
        expect(death.date).to eq("")
        expect(death.city).to eq("")
        expect(death.state).to eq("")
        expect(death.province).to eq("")
        expect(death.country).to eq("")
      end
    end
  end
end
