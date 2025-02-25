namespace :scihist do
  namespace :reports do
    desc """Export metadata to stdout for Google Arts and Culture (Feb. 2025).
      See https://github.com/sciencehistory/scihist_digicoll/issues/2893 .
      bundle exec rake scihist:reports:google_arts_and_culture_report_february_2025


    """

    task :google_arts_and_culture_report_february_2025 => :environment do

      include Rails.application.routes.url_helpers

      scope_1 = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Museum'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['physical_object'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['https://creativecommons.org/licenses/by/4.0/'] )

      scope_2 = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Library'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['image'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['http://creativecommons.org/publicdomain/mark/1.0/'] )

      ids_to_include = scope_1.or(scope_2).pluck(:id)

      base_url = ScihistDigicoll::Env.lookup!(:app_url_base)
      
      result = []

      ids_to_include.each do |id|
        w = Work.find(id)

        # Only include library works if they're published between 1450 and 1929
        if w.department == "Library"
          helper = DateIndexHelper.new(w)
          earliest = helper.min_date&.year
          latest =   helper.max_date&.year
          unless earliest.present? && earliest >= 1450 && latest.present? && latest <= 1929
            next
          end
        end
        
        members = w.members.where(published: true).where(type: 'Asset').order(:position)
        
        result << {
          id: w.friendlier_id,
          metadata: "#{base_url}/works/#{w.friendlier_id}.json",
          images: members.map { |mem| "#{base_url}/downloads/deriv/#{mem.friendlier_id}/download_full" }
        }
      end

      puts JSON.pretty_generate(result)
    end
  end
end
