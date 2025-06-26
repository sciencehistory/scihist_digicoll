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
    aws_region: ScihistDigicoll::Env.lookup!("aws_region"),
    acl: '', # parent default public ACL would be rejectec by our S3 bucket, now fronted by cloudfront
    # while we only re-gen once a day, we don't want lag time. Let cloudfront cache 10 minutes.
    cache_control: 'max-age=600, public'
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
  add api_docs_path, changefreq: 'monthly'

  add search_catalog_path, changefreq: 'daily'


  FeaturedTopic.all.collect(&:slug).each do |slug|
    add featured_topic_path(slug), changefreq: 'weekly'
  end

  ScihistDigicoll::Util.find_each(Collection.where(published: true)) do |c|
    add collection_path(c), changefreq: 'weekly', lastmod: nil
  end

  ScihistDigicoll::Util.find_each(Work.where(published: true).includes(:members => :leaf_representative)) do |w|

    # spec says we can add at most 1000 image URLs for each page. Let's add large thumbs
    # of all members, trying to use same URLs we'll use for src in page.
    member_representatives = w.members.find_all { |m| m.published? }.slice(0, 1000).collect(&:leaf_representative).compact

    image_urls = member_representatives.collect do |asset|
      asset.file_url("thumb_large_2X")
    end.compact

    add work_path(w), changefreq: 'monthly', lastmod: nil, images: image_urls.collect { |url| { loc: url } }

    # Add direct URLs to PDFs. We're adding the app URL that will 302 redirect to S3, with headers for inline display.
    pdf_members = member_representatives.find_all do |asset|
      asset.content_type == "application/pdf"
    end
    pdf_members.each do |pdf_asset|
      add download_path(pdf_asset.file_category, pdf_asset, disposition: :inline)
    end

    # if we have video transcripts, include them.
    member_representatives.find_all do |asset|
      asset.published? && asset.has_webvtt?
    end.each do |vtt_asset|
      add asset_transcript_path(vtt_asset)
    end
  end
end
