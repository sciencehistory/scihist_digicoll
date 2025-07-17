require 'rails_helper'

# Note: we have two Works controllers,
# works_controller.rb
# admin/works_controller.rb
# This one tests only the second.

# mostly we use feature tests, but some things can't easily be tested that way
# Should this be a 'request' spec instead of a rspec 'controller' spec
# (that is a rails 'functional' test)?
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

  context "#batch_publish_toggle", logged_in_user: :admin do
    let(:representative) {  build(:asset_with_faked_file, :tiff, published: true)}
    let(:publishable_work) { create(:work, :with_complete_metadata, published: false, members: [representative], representative: representative) }
    let(:unpublishable_work) { create(:work, published: false) }

    context "unpublishable works" do
      before do
        controller.current_user.works_in_cart << unpublishable_work
      end
      it "lists missing metadata on attempt to publish" do
        put :batch_publish_toggle, params: { publish: "on" }
        expect(response).to redirect_to(admin_cart_items_path)
        expect(flash["error"]).to match /Genre can.t be blank/
      end
    end

    context "work with corrupt file" do
      let(:corrupt_tiff_path) { Rails.root + "spec/test_support/images/corrupt_bad.tiff" }
      let(:bad_asset) {create(:asset, :inline_promoted_file, file: File.open(corrupt_tiff_path))}
      let(:good_asset) {create(:asset, :inline_promoted_file) }
      let(:work_with_bad_asset) { create(:work, :with_complete_metadata, published: false, members: [bad_asset, good_asset]) }
      before do
        controller.current_user.works_in_cart << unpublishable_work
        controller.current_user.works_in_cart << publishable_work
        controller.current_user.works_in_cart << work_with_bad_asset
      end
      it "displays error on attempt to publish" do
        put :batch_publish_toggle, params: { publish: "on" }
        expect(response).to redirect_to(admin_cart_items_path)
        expect(flash["error"]).to match /No changes made due to error/
      end
    end

    context "work with a png instead of a tiff" do
      let(:png) { create(:asset, :inline_promoted_file) }
      let(:work_with_png) { create(:work, :with_complete_metadata, published: false, members: [png]) }

      before do
        controller.current_user.works_in_cart << work_with_png
      end
      it "refuses to publish: image assets need to be tiffs unless they are portraits or collection thumbs." do
        expect(png.content_type).to eq "image/png"
        put :batch_publish_toggle, params: { publish: "on" }
        expect(response).to redirect_to(admin_cart_items_path)
        expect(flash["error"]).to match /contains one or more assets with invalid files./
        expect(work_with_png.reload.published?).to be false
      end
    end


    context "work with an asset with no mimetype" do
      let(:no_file_type) { create(:asset_with_faked_file, faked_content_type:nil) }
      let(:work_with_no_file_type) { create(:work, :with_complete_metadata, published: false, members: [no_file_type]) }
      before do
        controller.current_user.works_in_cart << work_with_no_file_type
      end
      it "refuses to publish: image assets need to be have a mime type." do
        expect(no_file_type.content_type).to be_nil
        put :batch_publish_toggle, params: { publish: "on" }
        expect(response).to redirect_to(admin_cart_items_path)
        expect(flash["error"]).to match /contains one or more assets with invalid files./
        expect(work_with_no_file_type.reload.published?).to be false
      end
    end

    context "work with a legitimate portrait png" do
      let(:portrait_png) { create(:asset, :inline_promoted_file, role: "portrait") }
      let(:work) { create(:work, :with_complete_metadata, published: false, members: [portrait_png]) }
      before do
        controller.current_user.works_in_cart << work
      end
      it "No error; should publish the work" do
        expect(publishable_work.members.first.content_type).to eq "image/tiff"
        put :batch_publish_toggle, params: { publish: "on" }
        expect(response).to redirect_to(admin_cart_items_path)
        expect(flash["error"]).to be nil
        expect(work.reload.published?).to be true
      end
    end

    context "publishable works" do
      around do |example|
        freeze_time do
          example.run
        end
      end

      before do
        controller.current_user.works_in_cart << publishable_work
      end

      it "publishes" do

        put :batch_publish_toggle, params: { publish: "on" }

        expect(response).to redirect_to(admin_cart_items_path)
        expect(flash["error"]).to be_blank

        expect(publishable_work.reload).to be_published
        expect(publishable_work.published_at).to eq Time.now
      end
    end
  end

  context "Oral histories", logged_in_user: :editor do
    let(:work) { create(:oral_history_work) }

    context "add an OHMS XML file" do
      let(:valid_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml" }

      it "can add valid file" do
        put :submit_ohms_xml, params: { id: work.friendlier_id, ohms_xml: Rack::Test::UploadedFile.new(valid_xml_path, "application/xml")}
        expect(response).to redirect_to(admin_work_path(work, anchor: "tab=nav-oral-histories"))
        expect(flash[:error]).to be_blank

        expect(work.reload.oral_history_content.ohms_xml).to be_present
      end

      it "can't add an invalid file" do
        put :submit_ohms_xml, params: {
          id: work.friendlier_id,
          ohms_xml: Rack::Test::UploadedFile.new(StringIO.new("not > xml"), "application/xml", original_filename: "foo.xml")
        }

        expect(response).to redirect_to(admin_work_path(work, anchor: "tab=nav-oral-histories"))
        expect(flash[:error]).to include("OHMS XML file was invalid and could not be accepted")

        expect(work.reload.oral_history_content&.ohms_xml).not_to be_present
      end
    end

    context "correcting timestamp sequence for multiple recordings" do
      let(:work) do
        create(:oral_history_work).tap do |awork|
          awork.oral_history_content!.output_sequenced_docx_transcript = build(:stored_uploaded_file)
        end
      end
      let(:docx_path) { Rails.root + "spec/test_support/oh_docx/sample-oh-timecode-need-sequencing.docx" }

      it "#store_input_docx_transcript" do
        # make sure we're testing what we expect
        expect(work.oral_history_content.output_sequenced_docx_transcript).to be_present
        expect(work.oral_history_content.input_docx_transcript_data).not_to be_present

        put :store_input_docx_transcript, params: {
          id: work.friendlier_id,
          docx: Rack::Test::UploadedFile.new(docx_path)
        }

        work.reload
        expect(work.oral_history_content.input_docx_transcript_data).to be_present
        # zero'd out since existing one no longer appropriate for new input
        expect(work.oral_history_content.output_sequenced_docx_transcript).not_to be_present
        expect(SequenceOhTimestampsJob).to have_been_enqueued.with(work)
      end
    end

    context "Adding, updating and removing full-text searches " do
      let(:transcript_path) { Rails.root + "spec/test_support/text/0767.txt" }
      let(:pdf_path) { Rails.root + "spec/test_support/pdf/sample.pdf" }

      let(:work) { FactoryBot.create(:work,
        genre: ["Oral histories"],
        external_id: [
          Work::ExternalId.new({"value"=>"0012",   "category"=>"interview"}),
        ])
      }

      it "can add a file" do
        put :submit_searchable_transcript_source, params: {
          id: work.friendlier_id,
          searchable_transcript_source: Rack::Test::UploadedFile.new(transcript_path, "text/plain")
        }
        expect(response).to redirect_to(admin_work_path(work, anchor: "tab=nav-oral-histories"))
        expect(flash[:error]).to be_blank
        expect(work.oral_history_content!.searchable_transcript_source).to be_present
      end

      it "can delete the file" do
        put :remove_searchable_transcript_source, params: {
          id: work.friendlier_id#,
        }
        expect(response).to redirect_to(admin_work_path(work, anchor: "tab=nav-oral-histories"))
        expect(flash[:error]).to be_blank
        expect(flash[:notice]).to match /has been removed/
        expect(work.oral_history_content!.searchable_transcript_source).not_to be_present
      end

      it "can download the file" do
        get :download_searchable_transcript_source, params: { id: work.friendlier_id }
        expect(response.status).to eq 200
        expect(response.header["Content-Disposition"]).to eq(
          "attachment; filename=\"0012_transcript.txt\"; filename*=UTF-8''0012_transcript.txt"
        )
      end
    end

    context "create audio derivatives",  logged_in_user: :admin do

      let!(:audio_asset_1)  { create(:asset, :inline_promoted_file,
          position: 1,
          title: "Audio asset 1",
          file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3"))
        )
      }
      let!(:audio_asset_2)  { create(:asset, :inline_promoted_file,
          position: 2,
          title: "Audio asset 2",
          file: File.open((Rails.root + "spec/test_support/audio/10-seconds-of-silence.mp3"))
        )
      }
      let!(:oral_history) { FactoryBot.create(
        :work,
        genre: ["Oral histories"],
        members: [audio_asset_1, audio_asset_2],
        title: "Oral history with two interview audio segments")
      }

      it "kicks off an audio derivatives job" do
        expect(oral_history.members.map(&:stored?)).to match([true, true])
        put :create_combined_audio_derivatives, params: { id: oral_history.friendlier_id }
        expect(response).to redirect_to(admin_work_path(oral_history, anchor: "tab=nav-oral-histories"))
        expect(CreateCombinedAudioDerivativesJob).to have_been_enqueued
      end
    end

    context "change oh available by request" do
      let(:was_true_asset) { create(:asset_with_faked_file, :mp3, oh_available_by_request: true) }
      let(:was_false_asset) { create(:asset_with_faked_file, :mp3, oh_available_by_request: false) }
      let(:work) { create(:oral_history_work, members: [was_true_asset, was_false_asset])}

      it "changes" do
        put :update_oh_available_by_request, params: {
          id: work.friendlier_id,
          oral_history_content: {
            available_by_request_mode: "automatic"
          },
          available_by_request: {
            was_true_asset.id => "false",
            was_false_asset.id => "true",
            "no_such_id" => "true"
          }
        }
        expect(response).to redirect_to(admin_work_path(work, anchor: "tab=nav-oral-histories"))

        expect(work.reload.oral_history_content.available_by_request_mode).to eq("automatic")
        expect(was_false_asset.reload.oh_available_by_request).to be true
        expect(was_true_asset.reload.oh_available_by_request).to be false
      end
    end

    context "update interviewee biography" do
      let(:interviewee_biography) { create(:interviewee_biography) }

      it "reindexes the work" do
        # cheesy hacky way to intercept solr index update method and ensure it happened
        expect_any_instance_of(Work).to receive(:update_index)

        put :update_oral_history_content, params: {
          id: work.friendlier_id,
          oral_history_content: {
            interviewee_biography_ids: [interviewee_biography.id]
          }
        }

        expect(work.oral_history_content.reload.interviewee_biography_ids).to eq([interviewee_biography.id])
      end
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
