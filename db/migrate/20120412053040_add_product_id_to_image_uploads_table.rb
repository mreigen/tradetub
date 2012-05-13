class AddProductIdToImageUploadsTable < ActiveRecord::Migration
  def self.up
    add_column :image_uploads, :product_id, :string, :null => false, :default => ""
  end

  def self.down
    remove_column :image_uploads, :product_id
  end
end
