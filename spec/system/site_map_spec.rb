require 'rails_helper'


describe "sitemap generator", js: false do
  # reset sitemap adapter to not send to s3, too hard to test for now
  # around(:each) do |example|
  #   $force_default_sitemap_adapter = true
  #   example.run
  #   $force_default_sitemap_adapter = false
  # end

  before(:all) do
    Rails.application.load_tasks

    spec = Gem::Specification.find_by_name 'sitemap_generator'
    load "#{spec.gem_dir}/lib/tasks/sitemap_generator_tasks.rake"
  end


  def loc_with_url(xml, url)
     xml.at_xpath("sitemap:urlset/sitemap:url/sitemap:loc[contains(text(), \"#{url}\")]", sitemap: "http://www.sitemaps.org/schemas/sitemap/0.9")
  end


  let(:asset) { create(:asset_with_faked_file) }
  let!(:work) { create(:work, representative: asset, members: [asset]) }
  let(:expected_work_url) { work_url(work, host: ScihistDigicoll::Env.app_url_base_parsed.host) }

  let!(:private_work) { create(:work, published: false) }
  let(:private_work_url) { work_url(private_work, host: ScihistDigicoll::Env.app_url_base_parsed.host) }

  let!(:collection) { create(:collection) }
  let(:expected_collection_url) { collection_url(collection, host: ScihistDigicoll::Env.app_url_base_parsed.host) }

  let(:expected_topic_url) { featured_topic_url(FeaturedTopic.all.first.slug, host: ScihistDigicoll::Env.app_url_base_parsed.host) }

  it "smoke tests" do


    Rake::Task["sitemap:create"].invoke

    Zlib::GzipReader.open(Rails.root + "public/sitemap/sitemap.xml.gz") do |gz_stream|
      xml = Nokogiri::XML(gz_stream.read)

      expect(loc_with_url(xml, expected_collection_url)).to be_present
      expect(loc_with_url(xml, expected_topic_url)).to be_present

      loc = loc_with_url(xml, expected_work_url)
      expect(loc).to be_present

      image_tag = loc.parent.at_xpath("image:image", image: "http://www.google.com/schemas/sitemap-image/1.1")
      expect(image_tag.text).to be_present

      expect(
        loc_with_url(xml, private_work_url)
      ).not_to be_present
    end
  end
end
