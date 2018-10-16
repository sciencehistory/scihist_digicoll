# This migration comes from kithe_engine (originally 20181015143259)
class EnablePgcryptoExtension < ActiveRecord::Migration[5.2]
  def change
    # for Rails UUID support, for UUID-generating it uses this.
    enable_extension 'pgcrypto'
  end
end
