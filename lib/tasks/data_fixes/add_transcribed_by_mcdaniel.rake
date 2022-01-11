namespace :scihist do
  namespace :data_fixes do
    desc """
      Add 'Transcribed by Jocelyn R. McDaniel' to Bredig documents that currently
      have the metadata 'Translated by Jocelyn R. McDaniel'
      https://github.com/sciencehistory/scihist_digicoll/issues/1525
    """

    task :add_transcribed_by_mcdaniel => :environment do
      bredig_collection_id = ENV['SOURCE_COL_ID'] || 'qfih5hl'
      scope = Collection.find_by_friendlier_id(bredig_collection_id).contains

      changed = 0

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          if ( work.additional_credit.find { |ac| ac.name == "Jocelyn R. McDaniel" && ac.role == "translated_by"} &&
               !work.additional_credit.find { |ac| ac.name == "Jocelyn R. McDaniel" && ac.role == "transcribed_by"}
          )
            work.additional_credit << Work::AdditionalCredit.new(name: "Jocelyn R. McDaniel", role: "transcribed_by")
            work.save!
            changed += 1
          end
          progress_bar.increment
        end
      end

      puts "updated #{changed} works"
    end
  end
end
