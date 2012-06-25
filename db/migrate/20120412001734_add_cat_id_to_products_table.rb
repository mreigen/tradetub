class AddCatIdToProductsTable < ActiveRecord::Migration
  def self.up
    add_column :items, :cat_id, :string
  end

  def self.down
    remove_column :items, :cat_id
  end
end
