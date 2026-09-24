require 'rails_helper'

RSpec.describe Admin::BatchReplaceMetadataController, logged_in_user: :editor, type: :controller, queue_adapter: :test do
  context "with a staff_viewer (no edit permission)", :logged_in_user do
    it "refuses #create" do
      post :create, params: { field_name: "description", old_value: "x", new_value: "y" }
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to match /You don't have permission/
    end
  end

  describe "#preview" do
    let!(:matching_work) { create(:work, description: "a widget") }
    let!(:other_work) { create(:work, description: "nothing here") }

    it "shows the matching works" do
      get :preview, params: { field_name: "description", old_value: "a widget", new_value: "a gadget" }

      expect(response).to have_http_status(200)
      expect(assigns(:form).matching_work_count).to eq(1)
      expect(assigns(:works_to_list)).to contain_exactly(matching_work)
    end

    it "re-renders the form with errors on invalid input" do
      get :preview, params: { field_name: "description", old_value: "", new_value: "gadget" }

      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
    end

    it "limits the list to 50 unless show_all is given" do
      allow_any_instance_of(Admin::BatchReplaceMetadataForm).to receive(:matching_works).and_return(Array.new(60) { matching_work })

      get :preview, params: { field_name: "description", old_value: "widget", new_value: "gadget" }
      expect(assigns(:works_to_list).size).to eq(50)

      get :preview, params: { field_name: "description", old_value: "widget", new_value: "gadget", show_all: "1" }
      expect(assigns(:works_to_list).size).to eq(60)
    end
  end

  describe "#create" do
    let!(:work) { create(:work, description: "a widget") }

    it "performs the replacement and redirects" do
      post :create, params: { field_name: "description", old_value: "a widget", new_value: "a gadget" }

      expect(response).to redirect_to(admin_works_path)
      expect(flash[:notice]).to match /Replaced metadata in 1 work/
      expect(work.reload.description).to eq("a gadget")
    end

    it "re-renders the form with errors on invalid input" do
      post :create, params: { field_name: "not_a_real_field", old_value: "widget", new_value: "gadget" }

      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
    end

    it "re-renders the form with errors, changing nothing, if the replacement would make a matching work invalid" do
      work.update!(file_creator: "Center for Oral History")

      post :create, params: { field_name: "file_creator", old_value: "Center for Oral History", new_value: "not-a-valid-file-creator" }

      expect(response).to have_http_status(200)
      expect(response).to render_template(:new)
      expect(assigns(:form).errors[:base]).to be_present
      expect(flash[:notice]).to be_nil
      expect(work.reload.file_creator).to eq("Center for Oral History")
    end
  end
end
