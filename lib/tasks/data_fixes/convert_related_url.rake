namespace :scihist do
  namespace :data_fixes do

    # note `label` will sometimes be blank in new related_links, meaning URLs will show
    desc "convert related_url to related_link"
    task :convert_related_url => :environment do
      scope = Work.where("json_attributes -> 'related_url' IS NOT NULL AND json_attributes -> 'related_url' != '[]'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |work|
        related_urls = work.related_url.dup

        related_urls.each do |url|
          case url
          when %r{\A\s*https?://digital\.sciencehistory\.org/works}
            progress_bar.log("#{work.friendlier_id} related_work #{url}")
            work.related_link << RelatedLink.new(category: "related_work", url: url)
          when %r{\A\s*https?://archives\.sciencehistory\.org/}
            progress_bar.log("#{work.friendlier_id} finding_aid #{url}")
            work.related_link << RelatedLink.new(category: "finding_aid", url: url)
          when /\Ahttps?:\/\/guides\.othmerlibrary\.(chemheritage|sciencehistory)\.org\//
            progress_bar.log("#{work.friendlier_id} institute_libguide #{url}")
            new_url = url.sub("chemheritage.org", "sciencehistory.org")
            work.related_link << RelatedLink.new(category: "institute_libguide", url: new_url)
          when %r{\A\s*https?://www\.sciencehistory\.org/historical-profile/}
            progress_bar.log("#{work.friendlier_id} institute_biography #{url}")
            work.related_link << RelatedLink.new(category: "institute_biography", url: url)
          when %r{\A\s*https?://www\.sciencehistory\.org/distillations/video/}
            progress_bar.log("#{work.friendlier_id} distillations_video #{url}")
            work.related_link << RelatedLink.new(category: "distillations_video", url: url)
          when %r{\A\s*https?://www\.sciencehistory\.org/distillations/podcast/}
            progress_bar.log("#{work.friendlier_id} distillations_podcast #{url}")
            work.related_link << RelatedLink.new(category: "distillations_podcast", url: url)
          when %r{\A\s*https?://www\.sciencehistory\.org/distillations/}
            progress_bar.log("#{work.friendlier_id} distillations_article #{url}")
            work.related_link << RelatedLink.new(category: "distillations_article", url: url)
          when %r{\A\s*https?://.*\.sciencehistory\.org/}
            progress_bar.log("#{work.friendlier_id} other_internal #{url}")
            work.related_link << RelatedLink.new(category: "other_internal", url: url)
          else
            progress_bar.log("#{work.friendlier_id} other_external #{url}")
            work.related_link << RelatedLink.new(category: "other_external", url: url)
          end

          work.related_url.delete(url)
        end

        work.save!
        progress_bar.increment
      end
    end
  end
end
