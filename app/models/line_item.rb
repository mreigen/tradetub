class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :product
  
  def get_product
    Product.find(product_id)
  end
end
