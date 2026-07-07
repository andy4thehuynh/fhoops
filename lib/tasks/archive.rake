namespace :archive do
  desc "Import imessage-exporter output or a chat.db snapshot: bin/rails archive:import SOURCE=/path [TENANT=default]"
  task import: :environment do
    source = ENV["SOURCE"] or abort "Usage: bin/rails archive:import SOURCE=/path/to/export [TENANT=default]"

    Tenant.find_by!(name: ENV.fetch("TENANT", "default")).switch do
      result = Archive.import(source)
      puts "Imported #{result[:imported]} messages (#{result[:skipped]} already archived)"
    end
  end
end
