require 'csv'
namespace :scihist do
  namespace :data_fixes do
    desc """
      bundle exec rake scihist:data_fixes:mint_metadata_export > booth.csv
      heroku run rake  scihist:data_fixes:mint_metadata_export     --app scihist-digicoll-production > booth.csv

      For all Booth collection items that come up on a keyword search for `mint`,
      extract the four following fields to a .csv:
        dc:identifier
        dc:title
        dc:date
        dc:description
    """
    task :mint_metadata_export => :environment do
      booth_collection = Collection.find_by_friendlier_id('kk91fk97p')

      # These extra items probably should contain subject heading
      # 'Mint of the United States' but for whatever reason do not.
      # They do show up on a keyword search for "mint", so we're including them.
      extra_items = ['gfdq0pd','es6o6w0','o7ipnz2','g7dx9a5','n78s1gp','g3zks4g',
        'atvlzv4','bsuxl7b','o4nuf9m','1gyh1nl','swydm1a']
      
      csv_string = CSV.generate do |csv|
        csv << ['identifier', 'title', 'date', 'description']
        booth_collection.contains.find_each(batch_size: 10) do |work|
          next unless (work.subject.include? 'Mint of the United States') || (extra_items.include? work.friendlier_id)
          csv << ['identifier', 'title', 'date', 'description'].map do |column|
            Nokogiri::XML(WorkOaiDcSerialization.new(work).to_oai_dc).
              xpath("//dc:#{column}", dc:"http://purl.org/dc/elements/1.1/").
              map(&:to_xml).join
          end
        end
      end
      
      puts csv_string
    end
  end
end
