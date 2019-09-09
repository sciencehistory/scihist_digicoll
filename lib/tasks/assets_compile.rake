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

  # Sprockets has created assets at public/assets/{fingerprinted version}
  # We want to copy them to public/{nonfingerprinted version}
  #
  # Ie `public/assets/404-1eed...b07e.html`
  # To: `public/404.html`
  #
  # We use this, as you can see, for our compiled static 404 and 500 pages.
  # If we wanted to use it for other assets, we might do similar, but
  # copy to public/assets/ instead of public/, depending on needs.
  #
  # Background at:
  #   https://github.com/rails/sprockets-rails/issues/49#issuecomment-20535134
  #   https://stackoverflow.com/questions/17536023/rake-assetsprecompilenodigest-in-rails-4/26049002
  task :create_non_digest_assets => :"assets:environment"  do
    %w{404.html 500.html}.each do |file|
      digest_relative_path = Rails.application.assets.find_asset("404.html")&.digest_path

      if digest_relative_path
        digest_path          = Rails.root + 'public/assets' + digest_relative_path
        destination_path     = Rails.root + 'public/' + file

        logger.info "(Local asset_compile.rake) Copying to #{destination_path}"

        # Use FileUtils.copy_file with true third argument to copy
        # file attributes (eg mtime) too, as opposed to FileUtils.cp
        # Making symlnks with FileUtils.ln_s would be another option, not
        # sure if it would have unexpected issues.
        FileUtils.cp(digest_path, destination_path)
      else
        logger.warn "(Local asset_compile.rake) Could not find #{file} to copy"
      end
    end
  end
end
