class AddAdjustedPriceToOfferWantedItemsTables < ActiveRecord::Migration
  def self.up
    add_column :offer_items, :adjusted_price, :decimal, :precision => 8, :scale => 2
    add_column :wanted_items, :adjusted_price, :decimal, :precision => 8, :scale => 2
  end

  def self.down
    remove_column :offer_items, :adjusted_price
    remove_column :wanted_items, :adjusted_price
  end
end
