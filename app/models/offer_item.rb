class OfferItem < ActiveRecord::Base
  belongs_to :offer
  #validates_uniqueness_of :item_id, :scope => :offer_id, :message => "Error: at least an offer item has already been used in an offer"

  def item
    Item.find(item_id)
  end
  
  def get_main_image(size)
    Item.find(item_id).get_main_image(size)
  end
end