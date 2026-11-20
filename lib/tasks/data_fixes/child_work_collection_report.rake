namespace :scihist do
  namespace :data_fixes do
    desc """Find child works whose collections differ from their parent's, writes three CSVs.
      bundle exec rake scihist:data_fixes:child_work_collection_report

      Optional OUTPUT_DIR env var (default: current dir).

      With UPLOAD=true, zips the CSVs and uploads to the Shrine cache storage (s3_bucket_uploads) instead, what you'll
      generally want on a deployed environment.
    """
    task :child_work_collection_report => :environment do
      upload = ENV['UPLOAD'] == 'true'
      tmp_dir = Dir.mktmpdir("child_work_collection_report") if upload
      output_dir = tmp_dir || ENV['OUTPUT_DIR'] || '.'

      headers = ['child_friendlier_id', 'child_title', 'child_collections', 'parent_title', 'parent_collections']
      files = {
        child_none_parent_some:   "child_no_collections_parent_has.csv",
        parent_has_not_on_child:  "child_has_parent_has_extra.csv",
        child_has_not_on_parent:  "child_has_collection_not_on_parent.csv"
      }

      csvs = files.transform_values { |name| CSV.open(File.join(output_dir, name), "w").tap { |c| c << headers } }

      begin
        Work.where.not(parent_id: nil).includes(:contained_by, parent: :contained_by).find_each do |child|
          parent = child.parent
          next unless parent

          child_ids  = child.contained_by.map(&:id)
          parent_ids = parent.contained_by.map(&:id)

          row = [
            child.friendlier_id,
            child.title,
            child.contained_by.map(&:title).join("; "),
            parent.title,
            parent.contained_by.map(&:title).join("; ")
          ]

          if child_ids.empty?
            csvs[:child_none_parent_some] << row if parent_ids.any?
          else
            csvs[:parent_has_not_on_child] << row if (parent_ids - child_ids).any?
          end

          csvs[:child_has_not_on_parent] << row if (child_ids - parent_ids).any?
        end
      ensure
        csvs.each_value(&:close)
      end

      if upload
        zip_name = "child_work_collection_report_#{ScihistDigicoll::Env.lookup(:service_level)}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.zip"
        zip_path = File.join(tmp_dir, zip_name)

        Zip::File.open(zip_path, create: true) do |zipfile|
          files.each_value { |name| zipfile.add(name, File.join(output_dir, name)) }
        end

        storage = ScihistDigicoll::Env.shrine_cache_storage
        File.open(zip_path, "rb") { |io| storage.upload(io, zip_name) }

        if storage.respond_to?(:bucket)
          $stderr.puts "Uploaded s3://#{storage.bucket.name}/#{storage.object(zip_name).key}"
        else
          $stderr.puts "Uploaded #{zip_name} to #{storage.class} (not S3)"
        end
        FileUtils.remove_entry(tmp_dir)
      else
        files.each_value { |name| $stderr.puts "Wrote #{File.join(output_dir, name)}" }
      end
    end
  end
end
