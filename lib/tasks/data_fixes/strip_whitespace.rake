namespace :scihist do
  namespace :data_fixes do

    desc "Remove trailing/leading whitespace from attributes in db for works"
    task :work_attr_strip_whitespace => :environment do
      if ENV['DRY_RUN'] == "true"
        puts "DRY RUN\n\n"
      else
        puts "CHANGiNG DATA\n\n"
      end

      remover = WorkAttrStripWhitespaceRemover.new(dry_run: ENV['DRY_RUN'] == "true")

      Kithe::Indexable.index_with(batching: true) do
        Work.find_each do |work|
          remover.exec_for_work(work)
        end
      end

      puts remover.counts
      puts "touched #{remover.works_identified.count} records"
    end
  end
end


# Pretty hacky and under-documented implementation, we don't plan to use it after
# running the data fix, just utilities as we figured that out.
#
# Skips the "description" and "admin_notes" fields in trimming, cause there were just so many of them,
# and the ending newlines don't really matter.
#
#   c = WorkAttrStripWhitespaceRemover.new(dry_run: true)
#   Kithe::Indexable.index_with(disable_callbacks: true) {  Work.find_each { |work| c.exec_for_work(work)  } }
#   puts c.counts
#   puts c.labels_identified
#
class WorkAttrStripWhitespaceRemover
  attr_reader :counts, :work_attributes_found

  attr_accessor :dry_run

  def initialize(dry_run:)
    @dry_run = dry_run
    reset_counts
  end

  def reset_counts
    @counts = Hash.new(0)
    @work_attributes_found = Hash.new { |hash, key| hash[key] = Set.new }
  end

  def exec_for_work(work)
     hash_recurse(work.json_attributes.as_json, work: work)

     if !dry_run && work.changed?
      # save any changes that were made
      work.save!
    end
  end

  def works_identified
    work_attributes_found.keys
  end

  private

  # If dry_run is false, this will actually strip whitespace from values in json_attributes
  # hash passed in (but wont' actually save work)
  #
  # If dry_run is true, jsut adds to our reporting state, doesn't make any changes.
  def hash_recurse(obj, keypath:"", work:)
    if obj.kind_of?(Hash)
      obj.each_pair do |k, v|
        # skip some fields
        next if k.in?(["description", "admin_note"]) && keypath.blank?

        hash_recurse(v, keypath: (keypath.empty? ? k : keypath+".#{k}"), work: work)
      end
    elsif obj.kind_of?(Array)
      obj.each do |el|
        hash_recurse(el, keypath: keypath, work: work)
      end
    elsif obj.kind_of?(String)
      if obj.strip != obj
        @counts[keypath] += 1
        @work_attributes_found[work.friendlier_id] << keypath

        unless dry_run
          obj.strip!
        end

        #puts "Found whitespace: #{work_label}: #{keypath}: #{obj.inspect}"
      end
    end
  end
end
