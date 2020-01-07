require 'tempfile'

desc "Copy remote work from staging to local dev, with all data"
task :copy_data, :work_friendlier_id do |t, args|
  if fetch(:stage) == :production
    # just cause we haven't really thought it through...
    raise ArgumentError, "For safety, we do not support copy_data from production at present"
  end

  unless args[:work_friendlier_id]
    raise ArgumentError, "missing :work_friendlier_id arg"
  end


  Tempfile.open do |tempfile|

    on primary(:jobs) do |host|
      within release_path do
        with rails_env: fetch(:rails_env) do
          serialized_json = capture(:rake, "scihist:copy_staging_work:serialize_work[#{args[:work_friendlier_id]}]")

          tempfile.write(serialized_json)
          tempfile.rewind
        end
      end
    end

    run_locally do
      rake "scihist:copy_staging_work:restore_work[#{tempfile.path}]"
    end

  end
end
