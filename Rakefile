# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/heroku.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

# An ugly hack inspired by:
# https://blog.testdouble.com/posts/2022-08-15-migrating-postgres-extensions-to-the-heroku_ext_schema/
#
# The goal here is to have `rake db:setup` create a database that has pg_stat_statements and pgcrypto
# installed in heroku_ext.
#
# See https://help.heroku.com/ZOFBHJCJ/heroku-postgres-extension-changes-faq
# We want to do this *without* modifying `db/schema.rb` directly, since schema.rb is created automatically by
# bin/rails db:schema:load .
Rake::Task["db:schema:dump"].enhance do
  filepath = "db/schema.rb"
  schema = File.read(filepath)
  schema = schema.gsub(
  	/enable_extension "pg_stat_statements"/,
  	'execute("CREATE SCHEMA IF NOT EXISTS heroku_ext;\nCREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA heroku_ext;\n")'
  )
  schema = schema.gsub(
  	/enable_extension "pgcrypto"/,
  	'execute("CREATE SCHEMA IF NOT EXISTS heroku_ext;\nCREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA heroku_ext;\n")'
  )  
  File.open(filepath, "w") {|file| file.puts schema}
end