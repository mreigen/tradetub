class OfferItem < ActiveRecord::Base
  belongs_to :offer

  def product
    Product.find(self.product_id)
  end
end