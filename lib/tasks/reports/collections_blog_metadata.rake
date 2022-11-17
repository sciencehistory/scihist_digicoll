namespace :scihist do
  namespace :reports do
    desc """Export metadata to stdout for some data visualizations work.
      See https://github.com/sciencehistory/scihist_digicoll/issues/1927 .
      bundle exec rake scihist:reports:collections_blog_metadata
    """
    task :collections_blog_metadata => :environment do

      bredig_collection =  Collection.find_by_friendlier_id('qfih5hl')


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
          'Bredig?',
          'thumbnail url'
        ]
        Kithe::Indexable.index_with(batching: true) do
          Work.where(published: true).find_each do |work|
            by_bredig = work.creator.map { |item| item.value }.include? "Bredig, Georg, 1868-1944"
            in_bredig_collection =  work.contained_by.include? bredig_collection
            csv << [
              work.friendlier_id,
              work.title,
              work.creator.map { |item| item.value }.join("; "),
              work.place.map { |item| item.value }.join("; "),
              DateDisplayFormatter.new(work.date_of_work).display_dates.join("; "),
              work.genre.join("; "),
              work.external_id.map { |item| item.value }.join("; "),
              work.department,
              (by_bredig || in_bredig_collection) ? "bredig" : "not_bredig",
              "https://digital.sciencehistory.org/downloads/deriv/#{work&.leaf_representative&.friendlier_id}/thumb_large?disposition=inline"
            ]
          end
        end
      end
      puts csv_string
    end
  end
end
