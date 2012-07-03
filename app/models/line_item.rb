class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :item
  
  def get_item
    Item.find(item_id)
  end
end
