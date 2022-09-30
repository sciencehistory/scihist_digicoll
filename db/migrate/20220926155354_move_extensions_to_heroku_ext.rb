class MoveExtensionsToHerokuExt < ActiveRecord::Migration[6.1]

  def up
    execute <<~SQL
      ALTER TABLE kithe_models ALTER COLUMN id SET DEFAULT gen_random_uuid();
      DROP EXTENSION IF EXISTS pgcrypto;

    SQL
  end

  def down
    execute <<~SQL
      CREATE EXTENSION IF NOT EXISTS pgcrypto;
    SQL
  end
end


