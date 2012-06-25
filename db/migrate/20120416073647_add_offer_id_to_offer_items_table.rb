class AddOfferIdToOfferItemsTable < ActiveRecord::Migration
  def self.up
    add_column :offer_items, :offer_id, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :offer_items, :offer_id
  end
end
