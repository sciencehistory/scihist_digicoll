namespace :scihist do
  namespace :data_fixes do
    desc """
      Goes through all the oral histories and switches rights per https://github.com/sciencehistory/scihist_digicoll/issues/3346
      If rightsholder includes Science History Institute
        and the rights are CC
      then change the rights to “In Copyright.”

    rake scihist:data_fixes:change_oral_histories_rights

    """

    task :change_oral_histories_rights => :environment do

      scope = Work.where("json_attributes -> 'genre' ?  'Oral histories'").
        where("json_attributes ->> 'rights_holder' ilike '%Science History Institute%'").
        where("json_attributes ->> 'rights' ilike '%creativecommons%'")

      progress_bar = ProgressBar.create(total: scope.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

      in_copyright_url = 'http://rightsstatements.org/vocab/InC/1.0/'

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |w|
          w.rights = in_copyright_url
          w.save!
          progress_bar.increment
        end
      end

    end
  end
end
