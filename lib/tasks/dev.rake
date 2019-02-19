namespace :dev do
  namespace :user do
    desc 'Create a user without a password; they can request one from the UI. `RAILS_ENV=production bundle exec rake chf:user:create[newuser@chemheritage.org]`'
    task :create, [:email] => :environment do |t, args|
      u = User.create!(email: args[:email])
      puts "User created with email address #{u.email}."
      puts "Please request a password via the 'Forgot your password?' page."
    end

    namespace :test do
      desc 'Create a test user with a password; not secure for actual users'
      task :create, [:email, :pass] => :environment do |t, args|
        u = User.create!(email: args[:email], password: args[:pass])
        puts "Test user created"
      end
    end
  end
end
