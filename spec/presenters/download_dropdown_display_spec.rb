require 'rails_helper'

describe DownloadDropdownDisplay do
  let(:rendered) { Nokogiri::HTML.fragment(DownloadDropdownDisplay.new(asset, display_parent_work: asset.parent).display) }
  let(:div) { rendered.at_css("div.action-item.downloads") }

  describe "no derivatives existing" do
    let(:asset) do
      create(:asset_with_faked_file,
            faked_derivatives: [],
            parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end

    it "renders" do
      expect(div).to be_present

      ul = div.at_css("div.dropdown-menu.download-menu")
      expect(ul).to be_present

      expect(ul).to have_selector("h3.dropdown-header", text: "Rights")
      expect(ul).to have_selector("a.rights-statement.dropdown-item", text: /Public Domain/)

      expect(div).to have_selector(".dropdown-header", text: "Download selected image")
      expect(div).to have_selector("a.dropdown-item", text: /Original/)

      expect(div).not_to have_selector("a.dropdown-item", text: /Small JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Medium JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Large JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Full-sized JPG/)
    end
  end

  describe "with image file and derivatives" do
    let(:asset) do
      create(:asset_with_faked_file,
        faked_derivatives: [
          build(:faked_derivative, key: "download_small"),
          build(:faked_derivative, key: "download_medium"),
          build(:faked_derivative, key: "download_large"),
          build(:faked_derivative, key: "download_full") ],
        parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end

    it "renders asset download options" do
      expect(div).to be_present

      expect(div).to have_selector(".dropdown-header", text: "Download selected image")

      expect(div).to have_selector("a.dropdown-item", text: /Small JPG/)
      expect(div).to have_selector("a.dropdown-item", text: /Medium JPG/)
      expect(div).to have_selector("a.dropdown-item", text: /Large JPG/)
      expect(div).to have_selector("a.dropdown-item", text: /Full-sized JPG/)
      expect(div).to have_selector("a.dropdown-item", text: /Original/)

      sample_download_option = div.at_css("a.dropdown-item:contains('Large JPG')")
      expect(sample_download_option["href"]).to be_present
      expect(sample_download_option["data-analytics-category"]).to eq("Work")
      expect(sample_download_option["data-analytics-action"]).to eq("download_jpg_large")
      expect(sample_download_option["data-analytics-label"]).to eq(asset.parent.friendlier_id)
    end
  end

  describe "with a PDF file" do
    let(:asset) do
      create(:asset_with_faked_file, :pdf,
        faked_derivatives: [],
        parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end

    it "renders just original option" do
      expect(div).to be_present

      expect(div).to have_selector(".dropdown-header", text: "Download selected document")
      expect(div).to have_selector("a.dropdown-item", text: /Original/)

      expect(div).not_to have_selector("a.dropdown-item", text: /Small JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Medium JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Large JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Full-sized JPG/)
    end
  end

  describe "with an audio file" do
    let(:asset) do
      create(:asset_with_faked_file,
        faked_content_type: "audio/x-flac",
        faked_height: nil,
        faked_width: nil,
        faked_derivatives: [build(:faked_derivative, key: "small_mp3", uploaded_file: build(:stored_uploaded_file, content_type: "audio/mpeg"))],
        parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end

    it "renders just original option" do
      expect(div).to be_present

      expect(div).to have_selector(".dropdown-header", text: "Download selected file")
      expect(div).to have_selector("a.dropdown-item", text: /Original file.*FLAC/)
      expect(div).to have_selector("a.dropdown-item", text: /Optimized MP3/)

      expect(div).not_to have_selector("a.dropdown-item", text: /Small JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Medium JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Large JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Full-sized JPG/)
    end
  end

  describe "with parent work" do
    let(:rendered) { Nokogiri::HTML.fragment(DownloadDropdownDisplay.new(asset, display_parent_work: parent_work).display) }

    describe "with all image files" do
      let(:asset) do
        create(:asset_with_faked_file,
              faked_derivatives: [])
      end

      let(:parent_work) do
        create(:work, members: [asset, build(:asset_with_faked_file), build(:asset_with_faked_file)])
      end

      it "renders whole-work download options" do
        expect(div).to have_selector(".dropdown-header", text: "Download all 3 images")

        zip_option = div.at_css("a.dropdown-item:contains('ZIP')")
        expect(zip_option).to be_present
        expect(zip_option["data-trigger"]).to eq "on-demand-download"
        expect(zip_option["data-derivative-type"]).to eq "zip_file"
        expect(zip_option["data-work-id"]).to eq parent_work.friendlier_id
        expect(zip_option["data-analytics-category"]).to eq "Work"
        expect(zip_option["data-analytics-action"]).to eq "download_zip"
        expect(zip_option["data-analytics-label"]).to eq parent_work.friendlier_id

        pdf_option = div.at_css("a.dropdown-item:contains('PDF')")
        expect(pdf_option).to be_present
        expect(pdf_option["data-trigger"]).to eq "on-demand-download"
        expect(pdf_option["data-derivative-type"]).to eq "pdf_file"
        expect(pdf_option["data-work-id"]).to eq parent_work.friendlier_id
        expect(pdf_option["data-analytics-category"]).to eq "Work"
        expect(pdf_option["data-analytics-action"]).to eq "download_pdf"
        expect(pdf_option["data-analytics-label"]).to eq parent_work.friendlier_id
      end

      describe "template_only" do
        let(:rendered) { Nokogiri::HTML.fragment(DownloadDropdownDisplay.new(nil, display_parent_work: parent_work, viewer_template: true).display) }

        it "renders only slot" do
          expect(div).to have_selector(".dropdown-header", text: "Download selected image")
          expect(div).to have_selector('*[data-slot="selected-downloads"]')

          expect(div).not_to have_selector("a.dropdown-item", text: /Small JPG/)
          expect(div).not_to have_selector("a.dropdown-item", text: /Medium JPG/)
          expect(div).not_to have_selector("a.dropdown-item", text: /Large JPG/)
          expect(div).not_to have_selector("a.dropdown-item", text: /Full-sized JPG/)
        end
      end
    end

    describe "without image files" do
      let(:asset) do
        create(:asset_with_faked_file, :pdf,
              faked_derivatives: [])
      end

      let(:parent_work) do
        create(:work, members: [asset, build(:asset_with_faked_file, :mp3), build(:asset_with_faked_file, :mp3)])
      end

      it "does not render whole-work download options" do
        expect(div).not_to have_selector(".dropdown-header", text: "Download all 3 images")
        expect(div).not_to have_selector(".dropdown-item", text: /ZIP/)
      end
    end
  end

  describe "use_link" do
    let(:rendered) { Nokogiri::HTML.fragment(DownloadDropdownDisplay.new(asset, display_parent_work: asset.parent, use_link: true).display) }

    let(:asset) do
      create(:asset_with_faked_file,
        faked_content_type: "audio/x-flac",
        faked_height: nil,
        faked_width: nil,
        faked_derivatives: [build(:faked_derivative, key: "small_mp3", uploaded_file: build(:stored_uploaded_file, content_type: "audio/mpeg"))],
        parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end

    it "renders as <a> tag" do
      expect(div).to be_present

      link = div.at_css("a[data-toggle='dropdown']")
      expect(link).to be_present

      # bootstrap docs for dropdown with <a> suggest what should be there
      # https://getbootstrap.com/docs/4.0/components/dropdowns/
      expect(link["role"]).to eq "button"
      expect(link["href"]).to eq "#"
      expect(link["id"]).to be_present
      expect(link["aria-haspopup"]).to eq "true"
      expect(link["aria-expanded"]).to eq "false"

      menu = div.at_css("div[aria-labelledby='#{link["id"]}']")
      expect(menu).to be_present
      expect(
        menu.children.all? { |node| node["class"] =~ /\b(dropdown-divider|dropdown-item|dropdown-header)\b/}
      ).to be true
    end
  end

  describe "no rights statement" do
    let(:asset) { build(:asset, parent: build(:work)) }
    it "renders without error" do
      expect(div).to be_present
      expect(div).not_to have_selector("h3.dropdown-header", text: "Rights")
    end
  end

  # shouldn't normally happen, but does in tests sometimes, we don't want an error.
  describe "no parent" do
    let(:asset) { build(:asset) }
    it "renders without error" do
      expect(div).to be_present
    end
  end
end
