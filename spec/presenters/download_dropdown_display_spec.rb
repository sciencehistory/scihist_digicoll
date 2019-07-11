require 'rails_helper'

describe DownloadDropdownDisplay do
  let(:rendered) { Nokogiri::HTML.fragment(DownloadDropdownDisplay.new(asset).display) }
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
    end
  end

  describe "with a PDF file" do
    let(:asset) do
      create(:asset_with_faked_file,
        faked_content_type: "application/pdf",
        faked_height: nil,
        faked_width: nil,
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
