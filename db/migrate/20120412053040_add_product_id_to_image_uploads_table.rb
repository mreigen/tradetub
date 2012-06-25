class AddProductIdToImageUploadsTable < ActiveRecord::Migration
  def self.up
    add_column :image_uploads, :item_id, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :image_uploads, :item_id
  end
end
