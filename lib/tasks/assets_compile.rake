# Rails 4-5 doesn't create un-fingerprinted assets anymore, but we
# need our generated error html to be without fingerpints in filenames.
#
# https://bibwild.wordpress.com/2014/10/02/non-digested-asset-names-in-rails-4-your-options/
#
# A better way to do this might be to have `cap` look in the generated sprockets manifest to figure
# out the right filename to copy, but that is confusing, and this is what we have.

# Every time assets:precompile is called, trigger umlaut:create_non_digest_assets afterwards.
Rake::Task["assets:precompile"].enhance do
  Rake::Task["scihist:create_non_digest_assets"].invoke
end

namespace :scihist do

  # This seems to be basically how ordinary asset precompile
  # is logging, ugh.
  logger = Logger.new($stderr)

  # Based on suggestion at https://github.com/rails/sprockets-rails/issues/49#issuecomment-20535134
  task :create_non_digest_assets => :"assets:environment"  do
    non_digest_files_match = ["**/*.html"]

    manifest_path = Dir.glob(File.join(Rails.root, 'public/assets/.sprockets-manifest-*.json')).first
    manifest_data = JSON.load(File.new(manifest_path))

    manifest_data["assets"].each do |logical_path, digested_path|
      logical_pathname = Pathname.new logical_path

      if non_digest_files_match.any? {|testpath| logical_pathname.fnmatch?(testpath, File::FNM_PATHNAME) }
        full_digested_path    = File.join(Rails.root, 'public/assets', digested_path)
        full_nondigested_path = File.join(Rails.root, 'public/assets', logical_path)

        gz_digested_path = "#{full_digested_path}.gz"
        gz_nondigested_path = "#{full_nondigested_path}.gz"

        logger.info "(Local asset_compile.rake) Copying to #{full_nondigested_path}"

        # Use FileUtils.copy_file with true third argument to copy
        # file attributes (eg mtime) too, as opposed to FileUtils.cp
        # Making symlnks with FileUtils.ln_s would be another option, not
        # sure if it would have unexpected issues.
        FileUtils.copy_file full_digested_path, full_nondigested_path, true
        if File.exist?(gz_digested_path)
          FileUtils.copy_file gz_digested_path, gz_nondigested_path, true
        end
      end
    end
  end
end
