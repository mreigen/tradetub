class MakeNicknameColUniqueInCategoriesTable < ActiveRecord::Migration
  def self.up
    add_index :categories, :nickname, :unique => true
  end

  def self.down
  end
end
