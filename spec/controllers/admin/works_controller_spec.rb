require 'rails_helper'

# Note: we have two Works controllers,
# works_controller.rb
# admin/works_controller.rb
# This one tests only the second.

RSpec.describe Admin::WorksController, :logged_in_user, type: :controller, queue_adapter: :test do
  context "#demote_to_asset" do
    context "work not suitable" do
      context "because it has no parent" do
        let(:work) { FactoryBot.create(:work, :with_assets)}

        it "rejects" do
          put :demote_to_asset, params: { id: work.friendlier_id }

          expect(response).to redirect_to admin_work_path(work)
          expect(flash[:alert]).to match /Can't convert/
        end
      end

      context "because it has multiple assets" do
        let(:parent_work) { FactoryBot.create(:work) }
        let(:work) { FactoryBot.create(:work, :with_assets, asset_count: 5, parent: parent_work)}

        it "rejects" do
          put :demote_to_asset, params: { id: work.friendlier_id }

          expect(response).to redirect_to admin_work_path(work)
          expect(flash[:alert]).to match /Can't convert/
        end
      end
    end
  end

  context "#update", logged_in_user: :editor do
    let(:work) { create(:public_work, ocr_requested: true, members: [create(:asset_with_faked_file, hocr: "<random ocr/>")]) }
    it "trims leading and trailing spaces" do
      put :update, params: {
        id: work.friendlier_id,
        work: {
          title: "  title  ",
          creator_attributes: {
            "_kithe_placeholder"=>{"_destroy"=>"1"},
            "0"=>{"category"=>"author", "value"=>" creator1"},
            "1"=>{"category"=> "publisher", "value" => "publisher1 " }
          },
          medium_attributes: ["", " medium term "],
          rights_holder: "  rights holder "
        }
      }

      expect(response).to have_http_status(302)

      work.reload

      expect(work.rights_holder).to eq "rights holder"
      expect(work.medium).to eq(["medium term"])
      expect(work.title).to eq("title")
      expect(work.creator.collect(&:value)).to contain_exactly("creator1", "publisher1")
    end

    it "does NOT trim from specifically excluded fields" do
      put :update, params: {
        id: work.friendlier_id,
        work: {
          description: "paragraph1\nparagraph2\n",
          admin_note_attributes: ["paragraph1\nparagraph2\n"]
        }
      }

      work.reload

      expect(work.description).to eq "paragraph1\nparagraph2\n"
      expect(work.admin_note).to eq ["paragraph1\nparagraph2\n"]
    end

    it "queues a WorkOcrCreatorRemoverJob when ocr_requested is turned off" do
      expect {
        put :update, params: { id: work.friendlier_id, work: { ocr_requested: "0" } }
      }.to have_enqueued_job(WorkOcrCreatorRemoverJob).with { |w| expect(w.friendlier_id).to eq work.friendlier_id }

      expect(flash[:notice]).to match /Work was successfully updated./
    end

    it "does not delete OCR if the save operation fails" do
      put :update, params: { id: work.friendlier_id, work: { title: nil } }
      expect(flash[:notice]).to be_nil
      expect(work.reload.members.first.hocr).to eq "<random ocr/>"
    end
  end

  context "Reorder members", logged_in_user: :editor do
    let(:c)  { create(:asset_with_faked_file, :mp3, title: "c", position: 1) }
    let(:b)  { create(:asset_with_faked_file, :mp3, title: "b", position: 2) }
    let(:a)  { create(:asset_with_faked_file, :mp3, title: "a", position: 3) }
    let(:work) { create(:oral_history_work, members: [c, b, a])}
    it "can reorder by arbitrary order" do
      expect( work.members.order(:position).map {|member| member.title}).to eq ['c', 'b', 'a']
      put :reorder_members, params: {
        "controller" => "admin/works",
        "action" => "reorder_members",
        "ordered_member_ids" => [a.id, b.id, c.id ],
        "id" => work.friendlier_id
      }
      expect(response.status).to eq(302)
      expect( work.members.order(:position).map {|member| member.title}).to eq ['a', 'b', 'c']
    end
    it "can reorder alphabetically" do
      expect( work.members.order(:position).map {|member| member.title}).to eq ['c', 'b', 'a']
      put :reorder_members, params: {
        "controller" => "admin/works",
        "action" => "reorder_members",
        "id" => work.friendlier_id
      }
      expect(response.status).to eq(302)
      expect( work.members.order(:position).map {|member| member.title}).to eq ['a', 'b', 'c']
    end
  end

  context "protected to logged in users" do
    context "without a logged-in user", logged_in_user: false do
      it "redirects to login" do
        get :index
        expect(response).to redirect_to root_path
      end
    end

    context "with a logged-in user", logged_in_user: true do
      it "shows page" do
        get :index
        expect(response).not_to be_redirect
        expect(response.status).to eq(200)
      end

      context "sorting, filtering and pagination" do
        render_views
        let!(:works) { [
          create(:work, title: "work_a"),
          create(:work, title: "work_b")
        ] }

        it "sorts correctly by title" do
          get :index, params: { sort_field: :title, sort_order: :asc }
          rows = response.parsed_body.css('.table.admin-list tbody tr')
          expect(rows[0].inner_html).to include works[0].title
          expect(rows[1].inner_html).to include works[1].title
          get :index, params: { sort_field: :title, sort_order: :desc }
          rows = response.parsed_body.css('.table.admin-list tbody tr')
          expect(rows[0].inner_html).to include works[1].title
          expect(rows[1].inner_html).to include works[0].title
        end

        it "filters by partial title" do
          get :index, params:{"title_or_id"=> 'k_a' }
          rows = response.parsed_body.css('.table.admin-list tbody tr')
          expect(rows[0].inner_html).to include works[0].title
        end


        it "uses default sort with only include_child_works in the params" do
          get :index, params: { "include_child_works" => "true" }
          rows = response.parsed_body.css('.table.admin-list tbody tr')
          expect(rows[0].inner_html).to include works[1].title
          expect(rows[1].inner_html).to include works[0].title
        end

        # format is a reserved word
        # (see https://stackoverflow.com/questions/70726614/ruby-on-rails-use-format-as-a-url-get-parameter )
        # so let's use work_format instead.
        it "can filter on work format using work_format param" do
          get :index, params: { work_format: "mixed_material" }
          rows = response.parsed_body.css('.table.admin-list tbody tr')
          expect(rows.length).to eq 0
        end

        it "can filter on work format using work_format param" do
          get :index, params: { work_format: "" }
          rows = response.parsed_body.css('.table.admin-list tbody tr')
          expect(rows.length).to eq 2
        end

        context "sql escaping" do
          let(:quotey_title) { " \\\''''  Bellen's \"lecture\" \\\'''' " }
          let!(:works) { [ create(:work, title: quotey_title) ] }
          it "matches title correctly despite quotes" do
            get :index, params:{"title_or_id"=> quotey_title }
            rows = response.parsed_body.css('.table.admin-list tbody tr')
            expect(rows.length).to eq 1
          end
        end

        context "sql escaping" do
          let(:quotey_title) { " \\\''''  Bellen's \"lecture\" \\\'''' " }
          let!(:works) { [
            create(:work, external_id: [ Work::ExternalId.new({"value"=>quotey_title, "category"=>"interview"}) ]),
          ] }
          it "matches external_id correctly despite quotes" do
            get :index, params:{"title_or_id"=> quotey_title }
            rows = response.parsed_body.css('.table.admin-list tbody tr')
            expect(rows.length).to eq 1
          end
        end





        # object bib item accn aspace interview
        context "filtering by external_id" do
          let!(:works) { [
            create(:work, title: "work_a", external_id: [
              Work::ExternalId.new({"value"=>"1111",   "category"=>"interview"}),
            ]),
            create(:work, title: "work_b", external_id: [
              Work::ExternalId.new({"value"=>"2222",   "category"=>"aspace"}),
            ]),
          ] }
          it "can filter on external id, regardless of the category of the ID" do
            get :index, params: { title_or_id: "1111" }
            rows = response.parsed_body.css('.table.admin-list tbody tr')
            expect(rows.length).to eq 1
            get :index, params: { title_or_id: "2222" }
            rows = response.parsed_body.css('.table.admin-list tbody tr')
            expect(rows.length).to eq 1
          end
        end

      end
    end
  end

  context "protected to admin users" do
    let(:work) { create(:work) }

    context "with a logged-in non-admin user" do
      it "can not publish" do
        put :publish, params: { id: work.friendlier_id }
        expect(response.status).to redirect_to(root_path)
        expect(flash[:alert]).to match /You don't have permission/
      end

      it "can not delete" do
        put :destroy, params: { id: work.friendlier_id }
        expect(response.status).to redirect_to(root_path)
        expect(flash[:alert]).to match /You don't have permission/
      end
    end

    context "with a logged-in admin user", logged_in_user: :admin do
      # works that have the necessary metadata to be published, but aren't actually published yet
      let(:work_child) { build(:work, :published, published: false) }
      let(:asset_child) { build(:asset_with_faked_file, :tiff, published: false) }
      let(:work) do
        create(:work, :published, published: false, published_at: nil, members: [asset_child, work_child])
      end

      describe "publishing" do
        around do |example|
          freeze_time do
            example.run
          end
        end

        context "work has assets with invalid files" do
          let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }
          let(:bad_asset) {create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))}
          let(:good_asset) {create(:asset, :inline_promoted_file) }
          let(:parent_work) { create(:work, :with_complete_metadata, published: false, members: [bad_asset, good_asset]) }
          before do
            allow(Rails.logger).to receive(:warn)
          end
          it "refuses to publish" do
            expect(bad_asset.promotion_failed?).to be true
            put :publish, params: { id: parent_work.friendlier_id, cascade: 'true' }
            expect(response.status).to redirect_to(admin_work_path(parent_work, anchor: "tab=nav-members"))
            expect(Rails.logger).to have_received(:warn).with(/.*couldn't be published. Something was wrong with the file for asset*/)
          end
        end

        it "can publish, and publishes children" do
          expect(work.members.first.content_type).to eq "image/tiff"
          put :publish, params: { id: work.friendlier_id, cascade: 'true' }
          expect(response.status).to redirect_to(admin_work_path(work))
          work.reload
          expect(work.published?).to be true
          expect(work.published_at).to eq Time.now
          expect(work.members.all? {|m| m.published?}).to be true
        end

        it "does not change unpublished children unless requested" do
          put :publish, params: { id: work.friendlier_id, cascade: 'false' }
          expect(response.status).to redirect_to(admin_work_path(work))
          work.reload
          expect(work.published?).to be true
          expect(work.members.all? {|m| m.published?}).to be false
        end
      end


      it "can delete, and deletes children" do
        put :destroy, params: { id: work.friendlier_id }
        expect(response.status).to redirect_to(admin_works_path)
        expect(flash[:notice]).to match /was successfully destroyed/

        expect { work.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { work_child.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { asset_child.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context "work missing required fields for publication" do
        render_views

        let(:representative) {  build(:asset_with_faked_file, :tiff, published: true)}
        let(:work) { create(:private_work, rights: nil, format: nil, genre: nil, department: nil, date_of_work: nil, members: [representative], representative: representative)}

        it "can not publish, displaying proper error and work form" do
          put :publish, params: { id: work.friendlier_id, cascade: 'true' }
          expect(response.status).to be(200)

          expect(response.body).to include("Can&#39;t publish work: #{work.title}: Validation failed")
          expect(response.body).to include("Date can&#39;t be blank for published works")
          expect(response.body).to include("Rights can&#39;t be blank for published works")
          expect(response.body).to include("Format can&#39;t be blank for published works")
          expect(response.body).to include("Genre can&#39;t be blank for published works")
          expect(response.body).to include("Department can&#39;t be blank for published works")
        end

        describe "child work missing required fields" do
          let(:work_child) { build(:private_work, title: "the_child_work_title") }
          let(:work) do
            create(:work, :published, members: [work_child], published:false)
          end

          it "can not publish, displaing proper error for child work" do
            put :publish, params: { id: work.friendlier_id, cascade: 'true'}
            expect(response.status).to be(200)
            expect(response.body).to include("Can&#39;t publish work: #{work_child.title}: Validation failed")
          end
        end
      end

      context "published work" do
        let(:work_child) { build(:public_work) }
        let(:asset_child) { build(:asset, published: true) }
        let(:work) { create(:public_work, members: [asset_child, work_child]) }


        it "can unpublish, unpublishes children" do
          put :unpublish, params: { id: work.friendlier_id, cascade: 'true' }
          expect(response.status).to redirect_to(admin_work_path(work))

          work.reload
          expect(work.published?).to be false
          expect(work.members.none? {|m| m.published?}).to be true
        end

        it "does not change published children unless requested" do
          put :unpublish, params: { id: work.friendlier_id, cascade: 'false' }
          expect(response.status).to redirect_to(admin_work_path(work))

          work.reload
          expect(work.published?).to be false
          expect(work.members.all? {|m| m.published?}).to be true
        end
      end
    end
  end
end
