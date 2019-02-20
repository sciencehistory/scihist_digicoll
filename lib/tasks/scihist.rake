namespace :scihist do
  task :production_guard do
    if Rails.env.production? && ENV['PRODUCTION_OKAY'] != 'true'
      $stderr.puts "\nNot safe for production. If you are sure, run with `PRODUCTION_OKAY=true #{ARGV.join}`\n\n"
      exit 1
    end
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
end
