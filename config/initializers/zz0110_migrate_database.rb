# The Rails environment can be loaded for a bunch of reasons.
# Set $server_mode to true if it's really running as a server.
$server_mode = (
  $servlet_context or
  caller.any?{ |c| c =~ %r<commands/server|script/server> } or
  !ENV['FORCE_SERVER_MODE'].blank?)

if $server_mode
  # Run the migrations
  previous_version = ActiveRecord::Migrator.current_version
  ActiveRecord::Migrator.migrate("db/migrate/")
  current_version = ActiveRecord::Migrator.current_version

  # Load seeds
  load File.expand_path("db/seeds.rb", Rails.root) if previous_version == 0
end
