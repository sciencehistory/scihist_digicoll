namespace :scihist do
  namespace :reports do
    desc """Export metadata to stdout for some data visualizations work.
      See https://github.com/sciencehistory/scihist_digicoll/issues/1927 .
      bundle exec rake scihist:reports:collections_blog_metadata
    """
    task :collections_blog_metadata => :environment do
      csv_string = CSV.generate do |csv|
        csv << [
          'id',
          'title',
          'creators',
          'places',
          'dates',
          'genres',
          'external ids',
          'department',
        ]
        Kithe::Indexable.index_with(batching: true) do
          Work.where(published: true).find_each do |work|
            csv << [
              work.friendlier_id,
              work.title,
              work.creator.map { |item| item.value }.join("; "),
              work.place.map { |item| item.value }.join("; "),
              DateDisplayFormatter.new(work.date_of_work).display_dates.join("; "),
              work.genre.join("; "),
              work.external_id.map { |item| item.value }.join("; "),
              work.department
            ]
          end
        end
      end
      puts csv_string
    end
  end
end
