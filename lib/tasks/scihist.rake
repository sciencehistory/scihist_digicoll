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


  namespace :user do
    desc 'Create a user without a password; they can request one from the UI. `RAILS_ENV=production bundle exec rake chf:user:create[newuser@chemheritage.org]`'
    task :create, [:email] => :environment do |t, args|
      u = User.create!(email: args[:email])
      puts "User created with email address #{u.email}."
      puts "Please request a password via the 'Forgot your password?' page."
    end

    task :send_password_reset, [:email] => :environment do |t, args|
      user = User.find_by_email!(args[:email])
      user.send_reset_password_instructions
      puts "Password reset email sent to #{user.email}"
    end

    namespace :test do
      desc 'Create a test user with a password; not secure for actual users'
      task :create, [:email, :pass] => ["production_guard", :environment] do |t, args|
        u = User.create!(email: args[:email], password: args[:pass])
        puts "Test user created"
      end
    end

    namespace :admin do
      desc 'Grant admin role to existing user'
      task :grant, [:email] => :environment do |t, args|
        begin
          User.find_by_email!(args[:email]).update(admin: true)
        rescue ActiveRecord::RecordNotFound
          abort("User #{args[:email]} does not exist. Only an existing user can be promoted to admin")
        end
        puts "User: #{args[:email]} is an admin."
      end

      desc 'Revoke admin role from user'
      task :revoke, [:email] => :environment do |t, args|
        User.find_by_email!(args[:email]).update(admin: false)
        puts "User: #{args[:email]} is no longer an admin."
      end

      desc 'List all admin users'
      task list: :environment do
        puts "Admin users:"
        User.where(admin: true).each { |u| puts "  #{u.email}" }
      end
    end
  end

  namespace :solr do
    desc "sync all Works and Collections to solr index"
    task :reindex => :environment do
      scope = Kithe::Model.where(kithe_model_type: ["collection", "work"]) # we don't index Assets

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |model|
          progress_bar.title = "#{model.class.name}:#{model.friendlier_id}"
          model.update_index
          progress_bar.increment
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

  end
end
