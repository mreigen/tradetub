class AddCatIdToProductsTable < ActiveRecord::Migration
  def self.up
    add_column :products, :cat_id, :string
  end

  def self.down
    remove_column :products, :cat_id
  end
end
