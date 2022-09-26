# This migration comes from kithe_engine (originally 20181015143259)
class EnablePgcryptoExtension < ActiveRecord::Migration[5.2]
  def change
    # for Rails UUID support, for UUID-generating it uses this.
    execute "CREATE SCHEMA IF NOT EXISTS heroku_ext"
    execute "create extension pgcrypto with schema heroku_ext"
  end
end
