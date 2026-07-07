class Favorites::OrdersController < ApplicationController
  def update
    Contact.reorder_favorites(params.fetch(:contact_ids, []))
    head :no_content
  end
end
