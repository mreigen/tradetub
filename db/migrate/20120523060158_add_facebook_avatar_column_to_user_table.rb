class AddFacebookAvatarColumnToUserTable < ActiveRecord::Migration
  def self.up
    add_column :users, :facebook_avatar, :string
  end

  def self.down
    remove_column :users, :facebook_avatar
  end
end
