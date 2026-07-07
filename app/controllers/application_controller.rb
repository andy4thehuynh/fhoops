class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Every request runs against exactly one tenant's database.
  around_action :switch_to_current_tenant

  private
    def switch_to_current_tenant(&)
      current_tenant.switch(&)
    end

    # self_host runs the single tenant; hosted picks it from the subdomain
    # (alpha.ikeep.example → tenant "alpha").
    def current_tenant
      if Deployment.hosted?
        Tenant.find_by!(name: request.subdomains.first.to_s)
      else
        Tenant.default
      end
    end
end
