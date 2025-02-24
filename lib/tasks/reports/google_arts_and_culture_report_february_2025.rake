namespace :scihist do
  namespace :reports do
    desc """Export metadata to stdout for Google Arts and Culture (Feb. 2025).
      See https://github.com/sciencehistory/scihist_digicoll/issues/2893 .
      bundle exec rake scihist:reports:google_arts_and_culture_report_february_2025

      [
            Format = Physical Object
          AND
            Department = Museum
          AND
            Rights = Creative Commons Attribution 4.0 International License
      ]( should be 435 items as of 2/24/25 )

      OR

      [
          Format = Image
        AND
          Department = Library
        AND
          Rights = Public Domain Mark 1.0
        AND
          Date = 1450-1929
      ] (s/b 1882 items as of 2/24/25)


      For each work:        
        friendlier_id
        .json metadata url

      For each published image asset in these works, ordered by paqge number, we will need:
        image URL for full-sized JPEGs

    """

    task :google_arts_and_culture_report_february_2025 => :environment do

      include Rails.application.routes.url_helpers

      scope_1 = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Museum'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['physical_object'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['https://creativecommons.org/licenses/by/4.0/'] ).
      includes(:members)

      scope_2 = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Library'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['image'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['http://creativecommons.org/publicdomain/mark/1.0/'] ).
      includes(:members).

      select do |w|
        helper = DateIndexHelper.new(w)
        earliest = helper.min_date&.year
        latest =   helper.max_date&.year
        earliest.present? && earliest >= 1450 && latest.present? && latest <= 1929
      end
      base_url = ScihistDigicoll::Env.lookup!(:app_url_base)
      works_to_include = scope_1.to_a + scope_2.to_a
      result = []
      works_to_include.each do |w|
        members = w.members.where(published: true).where(type: 'Asset').order(:position).includes(:leaf_representative)
        members.each do |mem|
          result << [ w.friendlier_id,  "#{base_url}/admin/asset_files/#{w.friendlier_id}.json",  "#{base_url}/downloads/deriv/#{mem.friendlier_id}/download_full" ]
        end
      end
      puts(JSON.pretty_generate(result))
    end
  end
end
