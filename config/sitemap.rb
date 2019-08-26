require 'sitemap_generator'
require 'scihist_digicoll/env'


SitemapGenerator::Sitemap.create(
  sitemaps_path: 'sitemap/',
  default_host: ScihistDigicoll::Env.lookup!(:app_url_base)
) do

  add about_path, changefreq: 'monthly'
  add policy_path, changefreq: 'monthly'
  add faq_path, changefreq: 'monthly'
  add contact_path, changefreq: 'monthly'

  add search_catalog_path, changefreq: 'daily'


  FeaturedTopic.all.collect(&:slug).each do |slug|
    add featured_topic_path(slug), changefreq: 'weekly'
  end

  Collection.where(published: true).find_each do |c|
    add collection_path(c), changefreq: 'weekly', lastmod: nil
  end

  Work.where(published: true).includes(:members => [:derivatives, { :leaf_representative => :derivatives}]).order("updated_at desc").find_each do |w|

    # spec says we can add at most 1000 image URLs for each page. Let's add large thumbs
    # of all members, trying to use same URLs we'll use for src in page.
    member_representatives = w.members.find_all { |m| m.published }.slice(0, 1000).collect(&:leaf_representative)

    image_urls = member_representatives.collect do |asset|
      asset.derivative_for("thumb_large_2X").try(:url)
    end.compact

    add work_path(w), changefreq: 'monthly', lastmod: nil, images: image_urls.collect { |url| { loc: url } }
  end
end
