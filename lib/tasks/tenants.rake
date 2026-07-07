namespace :tenants do
  desc "Provision a tenant (creates its database file): bin/rails tenants:provision NAME=alpha"
  task provision: :environment do
    tenant = Tenant.provision(ENV.fetch("NAME"))
    puts "Provisioned #{tenant.name} at #{tenant.database_path}"
  end

  desc "Delete a tenant and its database file: bin/rails tenants:delete NAME=alpha"
  task delete: :environment do
    tenant = Tenant.find_by!(name: ENV.fetch("NAME"))
    print "Delete tenant '#{tenant.name}' and #{tenant.database_path}? [y/N] "
    abort "Aborted" unless $stdin.gets.to_s.strip.casecmp?("y")

    tenant.purge!
    puts "Deleted #{tenant.name}"
  end

  desc "List tenants"
  task list: :environment do
    Tenant.order(:name).each do |tenant|
      size = tenant.database_path.exist? ? "#{tenant.database_path.size / 1024}KB" : "missing"
      puts "#{tenant.name}\t#{tenant.database_path} (#{size})"
    end
  end
end
