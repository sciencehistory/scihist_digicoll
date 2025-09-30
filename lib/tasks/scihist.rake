namespace :scihist do
  task :production_guard do
    if Rails.env.production? && ENV['PRODUCTION_OKAY'] != 'true'
      $stderr.puts "\nNot safe for production. If you are sure, run with `PRODUCTION_OKAY=true #{ARGV.join}`\n\n"
      exit 1
    end
  end

  desc "print out value for ScihistDigicoll::Env variable. eg ./bin/rake scihist:env_value[solr_url]"
  task "env_value", [:key] => :environment do |t, args|
    unless args[:key].present?
      puts "Error. Run as ./bin/rake scihist:env_value[some_key_name]"
      exit
    end
    puts "#{args[:key]}: #{ScihistDigicoll::Env.lookup(args[:key]).inspect}"
  end

  desc "create DZI files for all assets"
  task "lazy_create_dzi" => :environment do |t, args|
    progress_bar = ProgressBar.create(total: Kithe::Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
    Kithe::Asset.find_each do |asset|
      next unless asset.stored?
      next unless asset.content_type&.start_with?("image/")

      next if asset.dzi_package.exists?

      progress_bar.title = asset.friendlier_id
      asset.dzi_package.create
    rescue *FixityChecker::SHRINE_NOT_FOUND_ERRORS
      progress_bar.log("Missing original for #{asset.friendlier_id}")
    ensure
      progress_bar.increment
    end
  end

  desc "force create DZI for named assets: ./bin/rake scihist:create_dzi_for[friendlier_id1,friendlier_id2,...]"
  task "create_dzi_for" => :environment do |t, args|
    progress_bar = ProgressBar.create(total: args.to_a.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
    Kithe::Asset.where(friendlier_id: args.to_a).find_each do |asset|
      progress_bar.title = asset.friendlier_id
      asset.dzi_package.create
      progress_bar.increment
    end
  end


  namespace :user do
    desc 'Create a user without a password  `RAILS_ENV=production bundle exec rake scihist:user:create[newuser@sciencehistory.org]`'
    task :create, [:email] => :environment do |t, args|
      u = User.create!(email: args[:email])
      puts "User created with email address #{u.email}."
      unless ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
        puts "Please request a password via the 'Forgot your password?' page."
      end
    end

    desc 'Send a password reset to a given user: `RAILS_ENV=production bundle exec rake scihist:user:send_password_reset[user@sciencehistory.org]`'
    task :send_password_reset, [:email] => :environment do |t, args|
      if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
        abort """The app won't show the password reset form when it's in SSO mode, so we won't send out a link to that form.
          Use the console to reset database passwords, or unset :log_in_using_microsoft_sso"""
      end
      user = User.find_by_email!(args[:email])
      user.send_reset_password_instructions
      puts "Password reset email sent to #{user.email}"
    end

    namespace :test do
      desc 'Create a test user with a password; not secure for actual users'
      task :create, [:email, :pass] => ["production_guard", :environment] do |t, args|
        u = User.create!(email: args[:email], password: args[:pass])
        puts "Test user created."
        if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
          abort("Note that the app does not currently accept password logins, as :log_in_using_microsoft_sso is currently set.")
        end
      end
    end

    namespace :admin do
      desc 'Grant admin role to existing user'
      task :grant, [:email] => :environment do |t, args|
        begin
          User.find_by_email!(args[:email]).update(user_type: 'admin')
        rescue ActiveRecord::RecordNotFound
          abort("User #{args[:email]} does not exist. Only an existing user can be promoted to admin.")
        end
        puts "User: #{args[:email]} is an admin."
      end

      desc 'Revoke admin role from user'
      task :revoke, [:email] => :environment do |t, args|
        User.find_by_email!(args[:email]).update(user_type: 'editor')
        puts "User: #{args[:email]} is no longer an admin; they are an editor instead."
      end

      desc 'List all admin users'
      task list: :environment do
        puts "Admin users:"
        User.where(user_type: 'admin').each { |u| puts "  #{u.email}" }
      end
    end
  end

  namespace :solr do
    desc "sync all Works and Collections to solr index"
    task :reindex => :environment do
      # We have to pre-fetch :oral_history_content for owrks, but don't have that
      # for collection, so have to in two parts.

      Kithe.indexable_settings.writer_settings.merge!(
        "solr_writer.thread_pool" => 1,
        "solr_writer.http_timeout" => 8
      )


      Kithe::Indexable.index_with(batching: true) do

        unless ENV["PROGRESS_BAR"] == "false"
          progress_bar = ProgressBar.create(total: (Work.count + Collection.count), format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
        end

        # We need to load all :members (children) of each work, since they have content that we need in
        # the index, including transcription/translation text. This does slow down the bulk index
        # a bit, but not too bad.

        [
          Work.strict_loading.for_batch_indexing,
          Collection.strict_loading.includes(:contains_contained_by)
        ].each do |scope|
          # use util to try to minimize RAM use.
          # limiting batch size to 100 seems to have good effect on limiting RAM use
          ScihistDigicoll::Util.find_each(scope, batch_size: 50) do |model|
            progress_bar.title = "#{model.class.name}:#{model.friendlier_id}" if progress_bar
            model.update_index
            progress_bar.increment if progress_bar
          end
        end
      end
    end

    desc "delete any model objects in solr that no longer exist in the db"
    task :delete_orphans => :environment do
      deleted_ids = Kithe::SolrUtil.delete_solr_orphans
      puts "Deleted #{deleted_ids.count} Solr objects"
    end

    desc "delete ALL items from Solr"
    task :delete_all => [:environment, :production_guard] do
      Kithe::SolrUtil.delete_all
    end

    desc "print out mapped index hash for specified ID, eg rake scihist:solr:debug_indexing[adf232adf]"
    task :debug_indexing, [:friendlier_id] => [:environment] do |t, args|
      Kithe::Model.find_by_friendlier_id(args[:friendlier_id]).update_index(writer: Traject::DebugWriter.new({}))
    end
  end

  namespace :derivatives do
    desc "Dump all paths from storage (s3) to a PSTORE file for analysis"

    task :dump_paths => :environment do
      require 'pstore'

      ENV["DESTINATION"] ||= "./tmp/derivative_paths.pstore"


      s3_iterator = S3PathIterator.new(
        shrine_storage: ScihistDigicoll::Env.shrine_derivatives_storage,
        show_progress_bar: true,
        progress_bar_total: Asset.all_derivative_count
      )

      if File.exist?(ENV['DESTINATION'])
        FileUtils.rm(ENV['DESTINATION'])
      end

      store = PStore.new(ENV['DESTINATION'])

      store.transaction do
        # for bookkeeping save storage please
        store["SHRINE_STORAGE_RECORDED"] = ScihistDigicoll::Env.shrine_derivatives_storage.inspect

        s3_iterator.each_s3_path do |s3_path|
          store[s3_path] = "true"
        end
      end
    end


    desc "check all derivative references exist as files on storage from DB produced by :dump"
    task :check_paths => :environment do
      require 'pstore'

      ENV["SOURCE"] ||= "./tmp/derivative_paths.pstore"

      missing_count = 0
      checked_count = 0

      unless File.exist?(ENV['SOURCE'])
        raise ArgumentError.new("No pstore DB found at #{ENV["SOURCE"]}, create it with scihist:derivatives:dump_paths or set path in ENV SOURCE")
      end

      store = PStore.new(ENV['SOURCE'])

      store.transaction(true) do
        # kind of lame non-user-friendly, but it's what we got for now...
        puts "Checking for storage: #{ScihistDigicoll::Env.shrine_derivatives_storage.inspect}\n\n"
        puts "DB was created for storage: #{store["SHRINE_STORAGE_RECORDED"]}"

        progress_bar = ProgressBar.create(total: Kithe::Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

        Kithe::Asset.find_each do |asset|
          asset.file_derivatives.each_pair do |derivative_key, uploaded_file|
            s3_path = [uploaded_file.storage.prefix, uploaded_file.id].compact.join("/")

            unless store.root?(s3_path)
              missing_count += 1
              progress_bar.log("Missing file: #{asset.friendlier_id}:#{derivative_key}, #{uploaded_file.url(public: true)}")
            end

            checked_count += 1
          end
          progress_bar.increment
        end
      end

      puts "\n\nMissing derivative files: #{missing_count} out of #{checked_count} (#{(missing_count.to_f / checked_count * 100).round(2)}%)"
    end
  end
end
