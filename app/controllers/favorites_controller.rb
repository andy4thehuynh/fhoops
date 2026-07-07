class FavoritesController < ApplicationController
  def create
    Contact.find(params[:contact_id]).favorite!
    redirect_back_or_to root_path
  rescue Contact::FavoritesFull
    redirect_back_or_to root_path, alert: "Favorites are full — unpin one first (max #{Contact::MAX_FAVORITES})."
  end

  def destroy
    Contact.find(params[:id]).unfavorite!
    redirect_back_or_to root_path
  end
end
