class OffersController < ApplicationController
  def update
  end
  
  def show
  end
  
  def index
    @offers = Offer.where("user_id = ? OR sender_id = ?", current_user, current_user)
  end
  
end