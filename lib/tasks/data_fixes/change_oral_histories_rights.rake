namespace :scihist do
  namespace :data_fixes do
    desc """
      Goes through all the oral histories and switches rights per https://github.com/sciencehistory/scihist_digicoll/issues/3346
      If the rights are CC
      then change the rights to “In Copyright.”

    bundle exec bin/rake scihist:data_fixes:change_oral_histories_rights

    """

    task :change_oral_histories_rights => :environment do

      cc_licenses = Work.where("json_attributes -> 'genre' ?  'Oral histories'").
        where("json_attributes ->> 'rights' ilike '%creativecommons%'")

      blank_licenses = Work.where("json_attributes -> 'genre' ?  'Oral histories'").
        where("json_attributes ->> 'rights' is null")

      works_changed = []

      puts "CC licenses:    #{cc_licenses.count}"
      puts "Blank licenses: #{blank_licenses.count}"

      scope = cc_licenses.or(blank_licenses)

      progress_bar = ProgressBar.create(total: scope.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

      in_copyright_url = 'http://rightsstatements.org/vocab/InC/1.0/'

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |w|
          w.rights = in_copyright_url
          w.save!
          works_changed << w.friendlier_id
          progress_bar.increment
        end
      end

      puts "Done."
      puts "Works changed: #{works_changed}"

    end
  end
end
