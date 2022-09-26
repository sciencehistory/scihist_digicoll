# Adapted from https://blog.testdouble.com/posts/2022-08-15-migrating-postgres-extensions-to-the-heroku_ext_schema/

class MoveExtensionsToHerokuExt < ActiveRecord::Migration[6.1]

  def up
    drop_stuff_that_uses_these_extensions!
    drop_extensions!

    create_heroku_ext_schema!

    create_extensions!(schema_name: "heroku_ext")
    recreate_stuff_that_uses_these_extensions!
  end

  def down
    drop_stuff_that_uses_these_extensions!
    drop_extensions!

    # Don't drop the `heroku_ext` schema, since it already exists in Heroku

    create_extensions!(schema_name: "public")
    recreate_stuff_that_uses_these_extensions!
  end

  private

  # The default WAS: public.gen_random_uuid()
  # which referred to pg_random_uuid in $libdir/pgcrypto .
  # We don't actually need or want want to specify the public schema here.
  def drop_stuff_that_uses_these_extensions!
    execute <<~SQL
      ALTER TABLE kithe_models ALTER COLUMN id DROP DEFAULT;
    SQL
  end

  def drop_extensions!
    execute <<~SQL
      DROP EXTENSION IF EXISTS pg_stat_statements;
      DROP EXTENSION IF EXISTS pgcrypto;
    SQL
  end

  def create_heroku_ext_schema!
    execute <<~SQL
      CREATE SCHEMA IF NOT EXISTS heroku_ext;
    SQL
  end

  def create_extensions!(schema_name:)
    execute <<~SQL
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA #{schema_name};
      CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA #{schema_name};
    SQL
  end

  # Add the default gen_random_uuid() back into the kithe_models table.
  def recreate_stuff_that_uses_these_extensions!
    execute <<~SQL
       ALTER TABLE kithe_models ALTER COLUMN id SET DEFAULT gen_random_uuid();
    SQL
  end
end


