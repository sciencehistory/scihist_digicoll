require 'rails_helper'

describe DownloadDropdownComponent, type: :component do
  let(:rendered) { render_inline(DownloadDropdownComponent.new(asset, display_parent_work: asset.parent)) }
  let(:div) { rendered.at_css("div.action-item.downloads") }

  describe "no derivatives existing" do
    let(:asset) do
      create(:asset_with_faked_file,
            faked_derivatives: {},
            parent: build(:work, friendlier_id: "faked#{rand(1000000).to_s(16)}", rights: "http://creativecommons.org/publicdomain/mark/1.0/")
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

  describe "work with one image file and derivatives, and whole-work options" do
    let(:asset) do
      create(:asset_with_faked_file,
        faked_derivatives: {
          download_small: build(:stored_uploaded_file),
          download_medium: build(:stored_uploaded_file),
          download_large: build(:stored_uploaded_file),
          download_full: build(:stored_uploaded_file)
        },
        parent: build(:public_work, members: [], friendlier_id: "faked#{rand(1000000).to_s(16)}", rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end
    let(:options) { WorkDownloadOptionsCreator.new(work: asset.parent).options }
    let(:rendered) { render_inline(DownloadDropdownComponent.new(asset, display_parent_work: asset.parent, whole_work_options: options)) }

    it "renders asset download options" do
      expect(div).to be_present

      expect(div).to have_selector(".dropdown-header", text: "Download selected image")

      download_items = rendered.css("div.action-item.downloads a.dropdown-item").
        map {|a| a.text }

      expect(download_items.count).to eq 6
      expect(download_items[0]).to include "Public Domain"
      expect(download_items[1]).to include "PDF"
      expect(download_items[2]).to include "Small JPG"
      expect(download_items[3]).to include "Large JPG"
      expect(download_items[4]).to include "Full-sized JPG"
      expect(download_items[5]).to include "Original file"

      sample_download_option = div.at_css("a.dropdown-item:contains('Large JPG')")
      expect(sample_download_option["href"]).to be_present
      expect(sample_download_option["data-analytics-category"]).to eq("Work")
      expect(sample_download_option["data-analytics-action"]).to eq("download_jpg_large")
      expect(sample_download_option["data-analytics-label"]).to eq(asset.parent.friendlier_id)
    end
  end

  describe "work with two image files and derivatives" do
    let(:work) do
      build(:work, friendlier_id: "faked#{rand(1000000).to_s(16)}", rights: "http://creativecommons.org/publicdomain/mark/1.0/",
        members:
        [
          create(:asset_with_faked_file,
            faked_derivatives: {
              download_small: build(:stored_uploaded_file),
              download_medium: build(:stored_uploaded_file),
              download_large: build(:stored_uploaded_file),
              download_full: build(:stored_uploaded_file)
            }),
          create(:asset_with_faked_file,
            faked_derivatives: {
              download_small: build(:stored_uploaded_file),
              download_medium: build(:stored_uploaded_file),
              download_large: build(:stored_uploaded_file),
              download_full: build(:stored_uploaded_file)
            })
        ]
      )
    end
    let(:rendered) { render_inline(DownloadDropdownComponent.new(work.members.first, display_parent_work: work)) }

    it "renders asset download options" do
      expect(div).to be_present

      expect(div).to have_selector(".dropdown-header", text: "Download selected image")

      #pp rendered.css("div.action-item.downloads a.dropdown-item")

      download_items = rendered.css("div.action-item.downloads a.dropdown-item").
        map {|a| a.text }

      expect(download_items.count).to eq 5
      expect(download_items[0]).to include "Public Domain"
      expect(download_items[1]).to include "Small JPG"
      expect(download_items[2]).to include "Large JPG"
      expect(download_items[3]).to include "Full-sized JPG"
      expect(download_items[4]).to include "Original file"

      sample_download_option = div.at_css("a.dropdown-item:contains('Large JPG')")
      expect(sample_download_option["href"]).to be_present
      expect(sample_download_option["data-analytics-category"]).to eq("Work")
      expect(sample_download_option["data-analytics-action"]).to eq("download_jpg_large")
      expect(sample_download_option["data-analytics-label"]).to eq(work.friendlier_id)
    end
  end

  describe "with btn_class_name" do
    let(:asset) do
      create(:asset_with_faked_file,
        faked_derivatives: {
          download_small: build(:stored_uploaded_file)
        },
        parent: build(:work)
      )
    end

    let(:custom_class_name) { "btn-brand-main" }
    let(:rendered) { render_inline(DownloadDropdownComponent.new(asset, display_parent_work: asset.parent, btn_class_name: custom_class_name)) }

    it "renders proper btn class in html" do
      btn = div.at_css("button.btn")

      expect(btn).to be_present
      expect(btn.classes).to include(custom_class_name)
    end
  end

  describe "with a PDF file" do
    let(:asset) do
      create(:asset_with_faked_file, :pdf,
        faked_derivatives: {},
        parent: build(:work, :published, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
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
      expect(div).not_to have_selector("a.dropdown-item", text: /\APDF/)

      expect(div.css("a.dropdown-item").count).to be 2
    end
  end

  describe "with an audio file" do
    let(:asset) do
      create(:asset_with_faked_file,
        faked_content_type: "audio/x-flac",
        faked_height: nil,
        faked_width: nil,
        faked_derivatives: {
           "m4a"   => create(:stored_uploaded_file, content_type: "audio/mpeg"),
         },
        parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end

    it "renders just original option" do
      expect(div).to be_present

      expect(div).to have_selector("a.dropdown-item", text: /Original/)

      expect(div).not_to have_selector("a.dropdown-item", text: /Small JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Medium JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Large JPG/)
      expect(div).not_to have_selector("a.dropdown-item", text: /Full-sized JPG/)

      expect(div).to have_selector(".dropdown-header", text: "Download selected file")
      expect(div).to have_selector("a.dropdown-item", text: /Original file.*FLAC/)
      expect(div).to have_selector("a.dropdown-item", text: /M4A/)
    end
  end


  describe "with whole-work options" do
    let(:asset) { create(:asset_with_faked_file) }
    let(:work) { create(:public_work, members: [asset, build(:asset_with_faked_file)]) }
    let(:options) { WorkDownloadOptionsCreator.new(work: work).options }
    let(:component) { DownloadDropdownComponent.new(asset, display_parent_work: work, whole_work_options: options) }
    let(:rendered) { render_inline(component) }

    it "renders options and heading" do
      expect(div).to have_selector(".dropdown-header", text: "Download all 2 images")

      options.each do |option_conf|
        option_html = option = div.at_css("a.dropdown-item:contains('#{option_conf.label}')")

        expect(option_html).to be_present
        expect(option_html["href"]).to eq option_conf.url
        expect(option_html["data-analytics-action"]).to eq option_conf.analyticsAction

        option_conf.data_attrs.each_pair do |key, value|
          expect(option_html[ "data-#{key.to_s.dasherize}" ]).to eq value
        end
      end
    end

    describe "with empty whole-work options" do
      let(:component) { DownloadDropdownComponent.new(asset, display_parent_work: work, whole_work_options: []) }

      it "does not include whole-work download options" do
        expect(div).not_to have_selector(".dropdown-header", text: "Download all 3 images")
        expect(div).not_to have_selector("a.dropdown-item:contains('ZIP')")
        expect(div).not_to have_selector("a.dropdown-item:contains('PDF')")
      end
    end

    describe "as viewer_template" do
      let(:component) { DownloadDropdownComponent.new(nil, display_parent_work: work, viewer_template: true, whole_work_options: options) }

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

  describe "use_link" do
    let(:rendered) { render_inline(DownloadDropdownComponent.new(asset, display_parent_work: asset.parent, use_link: true)) }

    let(:asset) do
      create(:asset_with_faked_file,
        faked_content_type: "audio/x-flac",
        faked_height: nil,
        faked_width: nil,
        faked_derivatives: { :small_mp3 => build(:stored_uploaded_file, content_type: "audio/mpeg") },
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

  describe "aria_label" do
    let(:rendered) do
      render_inline(DownloadDropdownComponent.new(asset, display_parent_work: asset.parent, aria_label: "This is aria_label"))
    end


    let(:asset) do
      create(:asset_with_faked_file,
        faked_derivatives: {
          download_small: build(:stored_uploaded_file),
          download_medium: build(:stored_uploaded_file),
          download_large: build(:stored_uploaded_file),
          download_full: build(:stored_uploaded_file)
        },
        parent: build(:work, rights: "http://creativecommons.org/publicdomain/mark/1.0/")
      )
    end
    it "includes aria_label" do
      expect(div.at("button")["aria-label"]).to eq "This is aria_label"
    end
  end
end
