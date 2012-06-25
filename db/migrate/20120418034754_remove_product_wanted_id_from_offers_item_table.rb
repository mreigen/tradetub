class RemoveProductWantedIdFromOffersItemTable < ActiveRecord::Migration
  def self.up
    remove_column :offer_items, :product_wanted_id
  end

  def self.down
    add_column :offer_items, :product_wanted_id, :integer
  end
end
