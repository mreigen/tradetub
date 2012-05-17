class OfferItem < ActiveRecord::Base
  belongs_to :offer
  validates_uniqueness_of :product_id, :scope => :offer_id, :message => "Error: at least an offer item has already been used in an offer"

  def product
    Product.find(self.product_id)
  end
end