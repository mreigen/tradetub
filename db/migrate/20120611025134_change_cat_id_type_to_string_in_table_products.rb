class ChangeCatIdTypeToStringInTableProducts < ActiveRecord::Migration
  def self.up
    change_table :products do |t|
      t.change :cat_id, :string
    end
  end

  def self.down
    change_table :products do |t|
      t.change :cat_id, :integer
    end
  end
end
