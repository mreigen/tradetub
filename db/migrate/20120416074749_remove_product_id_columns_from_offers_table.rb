class RemoveProductIdColumnsFromOffersTable < ActiveRecord::Migration
  def self.up
    remove_column :offers, :sender_product_id
    remove_column :offers, :offer_item_id
  end

  def self.down
    add_column :offers, :sender_product_id, :integer
    add_column :offers, :offer_item_id, :integer
  end
end
