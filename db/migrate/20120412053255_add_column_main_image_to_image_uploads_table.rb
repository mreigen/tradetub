class AddColumnMainImageToImageUploadsTable < ActiveRecord::Migration
  def self.up
    add_column :image_uploads, :is_main_image, :boolean, :default => "false"
  end

  def self.down
    remove_column :image_uploads, :is_main_image
  end
end
