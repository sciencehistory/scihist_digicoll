class InstallNeighborVector < ActiveRecord::Migration[8.0]
  # we need at least pg_vector 0.7.0 for halfvec support etc,
  # let's insist upon the latest for consistency.
  #
  # This was admittedly created with AI.

  MINIMIM_VERSION = Gem::Version.new("0.8.0")

  def up
    # Check if already installed
    installed_version = select_value(<<~SQL)
      SELECT extversion
      FROM pg_extension
      WHERE extname = 'vector';
    SQL

    if installed_version.nil?
      # Not installed -> install specific version
      execute <<~SQL
        CREATE EXTENSION IF NOT EXISTS vector
        WITH VERSION '#{MINIMIM_VERSION}';
      SQL

      return
    end

    # Already installed -> compare versions
    if Gem::Version.new(installed_version) < MINIMIM_VERSION
      # Too old -> attempt upgrade
      execute <<~SQL
        ALTER EXTENSION vector UPDATE TO '#{MINIMIM_VERSION}';
      SQL

      # Recheck to confirm upgrade worked
      new_version = select_value("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
      if Gem::Version.new(new_version) < MINIMIM_VERSION
        raise "vector upgrade failed: still at #{new_version}, expected >= #{MINIMIM_VERSION}"
      end
    end
  end

  def down
    disable_extension "vector"
  end
end
