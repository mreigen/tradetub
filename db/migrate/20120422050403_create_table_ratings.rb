class CreateTableRatings < ActiveRecord::Migration
  def self.up
    create_table :ratings do |t|
      t.string :offer_id
      t.integer :score
      t.string :comment
    end
  end

  def self.down
    drop_table :ratings
  end
end
