class MoveExtensionsToHerokuExt < ActiveRecord::Migration[6.1]
  # Up until now, we only needed the `pgcrypto` postgres extension to get access to
  # gen_random_uuid(), which we use to generate new UUID primary keys for the kithe_models table.
  #
  # In postgres version 14, gen_random_uuid() is available as a core Postgres function;
  # now that our databases  are all running that version, we no longer need `pgcrypto`.
  def up
    execute <<~SQL
      ALTER TABLE kithe_models ALTER COLUMN id SET DEFAULT gen_random_uuid();
      DROP EXTENSION IF EXISTS pgcrypto;

    SQL
  end



  # Note: the default primary key value for the kithe_models used to
  # be public.gen_random_uuid().
  # We're not including this change in the `down` migration,
  # because we don't foresee the need to change the database version down to below version 14.
  def down
    execute <<~SQL
      CREATE EXTENSION IF NOT EXISTS pgcrypto;
    SQL
  end
end


