require 'rails_helper'
require 'rake'


describe "sitemap generator", js: false do
  # hacky way to tell sitemap generator NOT to send to s3, so we can test it.
  around(:each) do |example|
    $force_local_sitemap_generation = true
    example.run
    $force_local_sitemap_generation = false
  end

  before(:all) do
    #Rails.application.load_tasks

    # https://blog.10pines.com/2019/01/14/testing-rake-tasks/

    spec = Gem::Specification.find_by_name 'sitemap_generator'
    task_path = "#{spec.gem_dir}/lib/tasks/sitemap_generator_tasks.rake"

    Rake.application.rake_require "tasks/sitemap_generator_tasks" # actually from sitemap gem
    Rake::Task.define_task(:environment)
  end

  def loc_with_url(xml, url)
     xml.at_xpath("sitemap:urlset/sitemap:url/sitemap:loc[contains(text(), \"#{url}\")]", sitemap: "http://www.sitemaps.org/schemas/sitemap/0.9")
  end


  let(:asset) { create(:asset_with_faked_file) }
  let!(:work) { create(:work, representative: asset, members: [asset]) }
  let(:expected_work_url) { work_url(work) }

  let!(:private_work) { create(:work, published: false) }
  let(:private_work_url) { work_url(private_work) }

  let!(:collection) { create(:collection) }
  let(:expected_collection_url) { collection_url(collection) }

  let(:expected_topic_url) { featured_topic_url(FeaturedTopic.all.first.slug) }

  it "smoke tests" do
    Rake::Task["sitemap:create"].invoke

    sitemap_path = Rails.root + "public/" + ScihistDigicoll::Env.lookup!(:sitemap_path) + "sitemap.xml.gz"

    expect(File.exist?(sitemap_path)).to be(true)

    Zlib::GzipReader.open(sitemap_path) do |gz_stream|
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
