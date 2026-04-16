namespace :scihist do
  namespace :data_fixes do
    desc """
      Goes through all the oral histories and switches rights per https://github.com/sciencehistory/scihist_digicoll/issues/3346
      If the rights are CC
      then change the rights to “In Copyright.”

      DRY_RUN=true    bundle exec bin/rake scihist:data_fixes:change_oral_histories_rights

    """

    task :change_oral_histories_rights => :environment do

      works_changed = []

      scope = Work.where("json_attributes -> 'genre' ?  'Oral histories'")

      progress_bar = ProgressBar.create(total: scope.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

      in_copyright_url = 'http://rightsstatements.org/vocab/InC/1.0/'

      Kithe::Indexable.index_with(batching: true) do

        if ENV['DRY_RUN'] == "true"
          puts "DRY RUN\n\n"
        else
          puts "CHANGiNG DATA\n\n"
        end


        scope.find_each do |w|
          if  (!w.rights.present?) || w.rights.include?('creativecommons')
            old_rights = w.rights
            works_changed << [w.friendlier_id, old_rights]
            
            if ENV['DRY_RUN'] == "true"
              w.rights = in_copyright_url
              w.save!
            end

          end
          progress_bar.increment
        end
      end

      puts "Done."
      puts "Works changed: #{works_changed}"

    end
  end
end
