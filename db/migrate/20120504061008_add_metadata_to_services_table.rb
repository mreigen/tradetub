class AddMetadataToServicesTable < ActiveRecord::Migration
  def self.up
    add_column :services, :description, :string
    add_column :services, :price, :decimal, :precision => 8, :scale => 2
    add_column :services, :trade_type, :integer, :default => 0
    add_column :services, :available, :boolean, :default => true
  end

  def self.down
    remove_column :services, :description
    remove_column :services, :price
    remove_column :services, :trade_type
    remove_column :services, :available
  end
end
