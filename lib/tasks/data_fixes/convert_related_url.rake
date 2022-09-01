namespace :scihist do
  namespace :data_fixes do

    # note `label` will sometimes be blank in new related_links, meaning URLs will show
    desc "convert related_url to related_link"
    task :convert_related_url => :environment do
      scope = Work.where("json_attributes -> 'related_url' IS NOT NULL AND json_attributes -> 'related_url' != '[]'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      # for some known existing ones, supply label
      label_hash = {
        "http://guides.othmerlibrary.chemheritage.org/DyesandDyeing" => "History of Dyes and Dyeing",
        "http://www.encyclopedia.com/doc/1G2-2841300057.html" => "Crompton & Knowles Corp.",
        "https://www.sciencehistory.org/distillations/video/distilled-3-water-fit-for-a-king"=> "Distilled #3: Water Fit for a King",
        "https://www.sciencehistory.org/distillations/celluloid-the-eternal-substitute" => "Celluloid: The Eternal Substitute",
        "https://www.sciencehistory.org/distillations/video/distilled-8-penicillin-jug" => "Distilled #8: Penicillin Jug",
        "https://www.sciencehistory.org/distillations/braving-the-elements-why-mendeleev-left-russian-soil-for-american-oil" => "Braving the Elements: Why Mendeleev Left Russian Soil for American Oil",
        "https://www.sciencehistory.org/historical-profile/joseph-louis-gay-lussac" => "Joseph Louis Gay-Lussac",
        "http://archives.dickinson.edu/people/c-scott-althouse-1880-1970" => "C. Scott Althouse (1880-1970)",
        "https://catalog.hathitrust.org/Record/006496880" => "Über katalyse.",
        "https://www.sciencehistory.org/distillations/video/distilled-5-porcelain-painting" => "Distilled #5: Porcelain Painting",
        "http://www.sciencehistory.org/distillations/video/distilled-7-bicycle-horn-or-breast-pump" => "Distilled #7: Bicycle Horn or Breast Pump?",
        "https://www.sciencehistory.org/distillations/video/distilled-2-an-early-gold-plated-not-quite-iud" => "Distilled #2: An Early (Gold-Plated!) Not-Quite-IUD"
      }

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          related_urls = work.related_url.dup

          related_urls.each do |url|
            label = label_hash[url]

            case url
            when %r{\A\s*https?://digital\.sciencehistory\.org/works}
              progress_bar.log("#{work.friendlier_id} related_work #{url}")
              work.related_link << RelatedLink.new(category: "related_work", url: url, label: label)
            when %r{\A\s*https?://archives\.sciencehistory\.org/}
              progress_bar.log("#{work.friendlier_id} finding_aid #{url}")
              work.related_link << RelatedLink.new(category: "finding_aid", url: url, label: label)
            when /\Ahttps?:\/\/guides\.othmerlibrary\.(chemheritage|sciencehistory)\.org\//
              progress_bar.log("#{work.friendlier_id} institute_libguide #{url}")
              new_url = url.sub("chemheritage.org", "sciencehistory.org")
              work.related_link << RelatedLink.new(category: "institute_libguide", url: new_url, label: label)
            when %r{\A\s*https?://www\.sciencehistory\.org/historical-profile/}
              progress_bar.log("#{work.friendlier_id} institute_biography #{url}")
              work.related_link << RelatedLink.new(category: "institute_biography", url: url, label: label)
            when %r{\A\s*https?://www\.sciencehistory\.org/distillations/video/}
              progress_bar.log("#{work.friendlier_id} distillations_video #{url}")
              work.related_link << RelatedLink.new(category: "distillations_video", url: url, label: label)
            when %r{\A\s*https?://www\.sciencehistory\.org/distillations/podcast/}
              progress_bar.log("#{work.friendlier_id} distillations_podcast #{url}")
              work.related_link << RelatedLink.new(category: "distillations_podcast", url: url, label: label)
            when %r{\A\s*https?://www\.sciencehistory\.org/distillations/}
              progress_bar.log("#{work.friendlier_id} distillations_article #{url}")
              work.related_link << RelatedLink.new(category: "distillations_article", url: url, label: label)
            when %r{\A\s*https?://.*\.sciencehistory\.org/}
              progress_bar.log("#{work.friendlier_id} other_internal #{url}")
              work.related_link << RelatedLink.new(category: "other_internal", url: url, label: label)
            else
              progress_bar.log("#{work.friendlier_id} other_external #{url}")
              work.related_link << RelatedLink.new(category: "other_external", url: url, label: label)
            end

            work.related_url.delete(url)
          end

          work.save!
          progress_bar.increment
        end
      end
    end
  end
end
