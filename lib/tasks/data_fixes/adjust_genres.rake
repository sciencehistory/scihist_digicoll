namespace :scihist do
  namespace :data_fixes do
    desc "Genre adjustments, per https://github.com/sciencehistory/scihist_digicoll/issues/1275"
    task :adjust_genres => :environment do
      adjustments = {
        'Clothing & dress' => "Clothing and dress",
        "Documents" => "Records (Documents)",
        "Medical equipment & supplies" => "Medical instruments and apparatus",
        "Money (Objects)" => "Money",
        "Negatives" => "Negatives (Photographs)",
        "Textiles" => "Textile fabrics",
        "Minutes (Records)" => nil,
      }
      changes = []
      errors = []
      progress_bar = ProgressBar.create(total: Work.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          Work.find_each(batch_size: 10) do |work|
            new_genre =  work.genre.filter_map { |g| adjustments.fetch(g, g) } 

            # Let's make this idempotent just in case. Don't append "Postcards" if the genre list already contains it.
            unless work.genre.include?('Postcards')
              new_genre << 'Postcards' if (work.title =~ /[Pp]ostcard/)
            end
            next if (work.genre <=>  new_genre) == 0
            changes <<  [ work.friendlier_id, work.title, work.genre, new_genre]
            unless work.update(genre: new_genre)
              errors << "Unable to update work #{work.friendlier_id}'s genre to #{ new_genre }"
            end
            progress_bar.increment
          end
        end
      end
      puts errors.join("; ")
      pp changes
    end
  end
end
