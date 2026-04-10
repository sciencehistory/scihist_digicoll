require 'rails_helper'

RSpec.describe Admin::GoogleArtsAndCultureDownloadsController, :logged_in_user, type: :controller, queue_adapter: :test do
  let(:default_members) do
    [
      create(:asset_with_faked_file, faked_content_type: "image/tiff")
    ]
  end

  let(:museum_work_attrs) do
    {
      title: "Museum",
      department: "Museum",
      format: ['physical_object'],
      rights: 'https://creativecommons.org/licenses/by/4.0/',
      created_at: Time.parse("2020-01-01"),
      updated_at: Time.parse("2021-01-01"),
      members: default_members
    }
  end

  let(:library_work_attrs) do
    {
      title: "Library",
      department: "Library",
      format: ['image'],
      rights: 'http://creativecommons.org/publicdomain/mark/1.0/',
      created_at: Time.parse("2022-01-01"),
      updated_at: Time.parse("2023-01-01"),
      members: default_members
    }
  end

  let(:archives_work_attrs) do
    {
      title: "Archives",
      department: "Archives",
      created_at: Time.parse("2022-01-01"),
      updated_at: Time.parse("2023-01-01"),
      members: default_members
    }
  end

  def create_work(attrs)
    create(:public_work, **attrs)
  end

  def cart_titles
    controller.current_user.works_in_cart.pluck(:title).sort
  end

  let!(:eligible_museum_work)  { create_work(museum_work_attrs) }
  let!(:eligible_library_work) { create_work(library_work_attrs) }
  let!(:archives_work)         { create_work(archives_work_attrs) }

  context "#load_into_cart", :admin_user do
    it "loads all eligible museum and library works into the cart" do
      expect(controller.current_user.works_in_cart.count).to eq 0

      get :load_into_cart

      expect(controller.current_user.works_in_cart.count).to eq 2
      expect(cart_titles).to eq(["Library", "Museum"])
    end

    it "does not load any works when date filters exclude all eligible works" do
      get :load_into_cart, params: {
        "load_into_cart" => {
          "created_at_start_date" => "2026-04-02",
          "created_at_end_date" => "2026-04-08",
          "modified_at_start_date" => "2026-04-08",
          "modified_at_end_date" => "2026-04-18"
        }
      }

      expect(controller.current_user.works_in_cart.count).to eq 0
    end

    context "when a candidate has the wrong department" do
      let(:candidate_attrs) do
        museum_work_attrs.merge(
          title: "Wrong department",
          department: "Archives"
        )
      end

      let!(:candidate_work) { create_work(candidate_attrs) }

      it "does not add it" do
        get :load_into_cart

        expect(cart_titles).to eq(["Library", "Museum"])
      end
    end

    context "when a museum candidate has the wrong format" do
      let(:candidate_attrs) do
        museum_work_attrs.merge(
          title: "Wrong museum format",
          format: ['image']
        )
      end

      let!(:candidate_work) { create_work(candidate_attrs) }

      it "does not add it" do
        get :load_into_cart

        expect(cart_titles).to eq(["Library", "Museum"])
      end
    end

    context "when a museum candidate has the wrong rights" do
      let(:candidate_attrs) do
        museum_work_attrs.merge(
          title: "Wrong museum rights",
          rights: 'http://creativecommons.org/publicdomain/mark/1.0/'
        )
      end

      let!(:candidate_work) { create_work(candidate_attrs) }

      it "does not add it" do
        get :load_into_cart

        expect(cart_titles).to eq(["Library", "Museum"])
      end
    end

    context "when a library candidate has the wrong format" do
      let(:candidate_attrs) do
        library_work_attrs.merge(
          title: "Wrong library format",
          format: ['physical_object']
        )
      end

      let!(:candidate_work) { create_work(candidate_attrs) }

      it "does not add it" do
        get :load_into_cart

        expect(cart_titles).to eq(["Library", "Museum"])
      end
    end

    context "when a library candidate has the wrong rights" do
      let(:candidate_attrs) do
        library_work_attrs.merge(
          title: "Wrong library rights",
          rights: 'https://creativecommons.org/licenses/by/4.0/'
        )
      end

      let!(:candidate_work) { create_work(candidate_attrs) }

      it "does not add it" do
        get :load_into_cart

        expect(cart_titles).to eq(["Library", "Museum"])
      end
    end

    context "when an otherwise-eligible work falls outside the created_at range" do
      context "before the start date" do
        let(:candidate_attrs) do
          museum_work_attrs.merge(
            title: "Created too early",
            created_at: Time.parse("2019-12-31")
          )
        end

        let!(:candidate_work) { create_work(candidate_attrs) }

        it "does not add it" do
          get :load_into_cart, params: {
            "load_into_cart" => {
              "created_at_start_date" => "2020-01-01"
            }
          }

          expect(cart_titles).to eq(["Library", "Museum"])
        end
      end

      context "after the end date" do
        let(:candidate_attrs) do
          library_work_attrs.merge(
            title: "Created too late",
            created_at: Time.parse("2022-01-02")
          )
        end

        let!(:candidate_work) { create_work(candidate_attrs) }

        it "does not add it" do
          #pp candidate_attrs # library item was created at 2022-01-02
          get :load_into_cart, params: {
            "load_into_cart" => {
              "created_at_end_date" => "2022-01-01"
            }
          }

          expect(cart_titles).to eq(["Library", "Museum"])
        end
      end
    end

    context "when an otherwise-eligible work falls outside the modified_at range" do
      context "before the start date" do
        let(:candidate_attrs) do
          museum_work_attrs.merge(
            title: "Modified too early",
            updated_at: Time.parse("2020-12-31")
          )
        end

        let!(:candidate_work) { create_work(candidate_attrs) }

        it "does not add it" do
          get :load_into_cart, params: {
            "load_into_cart" => {
              "modified_at_start_date" => "2021-01-01"
            }
          }

          expect(cart_titles).to eq(["Library", "Museum"])
        end
      end

      context "after the end date" do
        let(:candidate_attrs) do
          library_work_attrs.merge(
            title: "Modified too late",
            updated_at: Time.parse("2023-01-02")
          )
        end

        let!(:candidate_work) { create_work(candidate_attrs) }

        it "does not add it" do
          get :load_into_cart, params: {
            "load_into_cart" => {
              "modified_at_end_date" => "2023-01-01"
            }
          }

          expect(cart_titles).to eq(["Library", "Museum"])
        end
      end
    end

    context "when ineligible works are within the supplied date ranges" do
      let!(:wrong_museum_format_work) do
        create_work(
          museum_work_attrs.merge(
            title: "In range wrong museum format",
            format: ['image'],
            created_at: Time.parse("2020-06-01"),
            updated_at: Time.parse("2021-06-01")
          )
        )
      end

      let!(:wrong_library_rights_work) do
        create_work(
          library_work_attrs.merge(
            title: "In range wrong library rights",
            rights: 'https://creativecommons.org/licenses/by/4.0/',
            created_at: Time.parse("2022-06-01"),
            updated_at: Time.parse("2023-06-01")
          )
        )
      end

      it "still excludes them" do
        get :load_into_cart, params: {
          "load_into_cart" => {
            "created_at_start_date" => "2020-01-01",
            "created_at_end_date" => "2022-12-31",
            "modified_at_start_date" => "2021-01-01",
            "modified_at_end_date" => "2023-12-31"
          }
        }

        expect(cart_titles).to eq(["Library", "Museum"])
      end
    end
  end

  context "export GAC" do
    let(:scope) { Work.where(id: [work_1.id, work_2.id]) }

    # it "builds a zip file that includes a manifest.csv and asset entries" do
    #   get :export_cart
    #
    #   expect(response).to have_http_status(:found)
    #   expect(response.headers['Content-Type']).to eq('application/zip')
    #   expect(response.headers['Content-Disposition']).to include "attachment; filename=\"google-arts-and-culture-export-#{Date.today.to_s}.zip\""
    #
    #   entry_names = []
    #   zip_io = StringIO.new(response.body)
    #
    #   Zip::InputStream.open(zip_io) do |io|
    #     while entry = io.get_next_entry
    #       entry_names << entry.name
    #     end
    #   end
    #
    #   expect(entry_names[0]).to eq "metadata.csv"
    #   expect(entry_names[1]).to match "test_title_.*\.jpg"
    #   expect(entry_names[2]).to match "test_title_.*\.jpg"
    # ensure
    #   zip_io.close if zip_io
    # end
  end
end