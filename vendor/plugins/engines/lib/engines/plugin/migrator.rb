# The Plugin::Migrator class contains the logic to run migrations from
# within plugin directories. The directory in which a plugin's migrations
# should be is determined by the Plugin#migration_directory method.
#
# To migrate a plugin, you can simple call the migrate method (Plugin#migrate)
# with the version number that plugin should be at. The plugin's migrations
# will then be used to migrate up (or down) to the given version.
#
# For more information, see Engines::RailsExtensions::Migrations
class Engines::Plugin::Migrator < ActiveRecord::Migrator

  # We need to be able to set the 'current' engine being migrated.
  cattr_accessor :current_plugin

  # Runs the migrations from a plugin, up (or down) to the version given
  def self.migrate_plugin(plugin, version)
    self.current_plugin = plugin
    # There seems to be a bug in Rails' own migrations, where migrating
    # to the existing version causes all migrations to be run where that
    # migration number doesn't exist (i.e. zero). We could fix this by
    # removing the line if the version hits zero...?
    return if current_version(plugin) == version
    migrate(plugin.migration_directory, version)
  end
  
  # Returns the name of the table used to store schema information about
  # installed plugins.
  #
  # See Engines.schema_info_table for more details.
  def self.schema_migrations_table_name
    proper_table_name Engines.schema_info_table
  end
  
  def self.schema_info_table_name
    # Legacy
    schema_migrations_table_name
  end
  
  def self.current_version(plugin=current_plugin)
    version = ::ActiveRecord::Base.connection.select_values(
      "SELECT version FROM #{schema_migrations_table_name} WHERE plugin_name = '#{plugin.name}'"
    ).map(&:to_i).max rescue nil
    version || 0
  end
  
  def migrated
    sm_table = self.class.schema_migrations_table_name
    plugin_name = self.class.current_plugin.name

    ::ActiveRecord::Base.connection.select_values("SELECT version FROM #{sm_table} WHERE plugin_name = '#{plugin_name}'").map(&:to_i).sort
  end
  
  # Sets the version of the plugin in Engines::Plugin::Migrator.current_plugin to
  # the given version.
  def record_version_state_after_migrating(version)
    sm_table = self.class.schema_migrations_table_name
    plugin_name = self.class.current_plugin.name

    if down?
      ::ActiveRecord::Base.connection.update("DELETE FROM #{sm_table} WHERE version = '#{version}' AND plugin_name = '#{plugin_name}'")
    else
      ::ActiveRecord::Base.connection.insert("INSERT INTO #{sm_table} (plugin_name, version) VALUES ('#{plugin_name}', '#{version}')")
    end
  end
end
