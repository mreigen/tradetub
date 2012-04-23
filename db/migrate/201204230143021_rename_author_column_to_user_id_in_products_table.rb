class RenameAuthorColumnToUserIdInProductsTable < ActiveRecord::Migration
  def self.up
    rename_column :products, :author, :user_id
  end
  
  def self.down
    rename_column :products, :user_id, :author
  end
end
