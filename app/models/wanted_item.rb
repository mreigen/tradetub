class WantedItem < ActiveRecord::Base
	belongs_to :offer

  def product
    Product.find(self.product_id)
  end
  
  def get_main_image(size)
    Item.find(item_id).get_main_image(size)
  end
end