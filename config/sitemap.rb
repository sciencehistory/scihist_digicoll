require 'sitemap_generator'
require 'scihist_digicoll/env'

#####
#
# Note on google and cross-domain stuff.
#
# We have our sitemaps on a different host than the main app -- currently on derivatives S3 bucket.
#
# We also include images in our sitemap that are located in derivatives bucket, and are currently linking
# directly to them.
#
# So, to get Google to use the sitemap and index those images, we need to 'claim' the production
# derivatives host in Google web admin tools. See:
#
# https://support.google.com/webmasters/answer/34592?visit_id=1-636531068483226339-3826640717&rd=1
#
#####


# Global variable hackily used only so tests can change it to not write to s3 under test
unless $force_local_sitemap_generation
  sitemap_adapter = SitemapGenerator::AwsSdkAdapter.new(
    ScihistDigicoll::Env.lookup!("s3_sitemap_bucket"),
    aws_access_key_id: ScihistDigicoll::Env.lookup!("aws_access_key_id"),
    aws_secret_access_key: ScihistDigicoll::Env.lookup!("aws_secret_access_key"),
    aws_region: ScihistDigicoll::Env.lookup!("aws_region")
  )
end

SitemapGenerator::Sitemap.create(
  sitemaps_path: ScihistDigicoll::Env.lookup!(:sitemap_path),
  default_host: ScihistDigicoll::Env.lookup!(:app_url_base),
  adapter: sitemap_adapter
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

  Work.where(published: true).includes(:members => :leaf_representative).order("updated_at desc").find_each do |w|

    # spec says we can add at most 1000 image URLs for each page. Let's add large thumbs
    # of all members, trying to use same URLs we'll use for src in page.
    member_representatives = w.members.find_all { |m| m.published? }.slice(0, 1000).collect(&:leaf_representative).compact

    image_urls = member_representatives.collect do |asset|
      asset.file_url("thumb_large_2X")
    end.compact

    add work_path(w), changefreq: 'monthly', lastmod: nil, images: image_urls.collect { |url| { loc: url } }
  end
end
