class AddResponsesToOffersTable < ActiveRecord::Migration
  def self.up
    # 0 : still deciding
    # 1 : accept
    # 2 : rejected
    # 3 : counter-offer
    add_column :offers, :response, :number, :default => 0
  end

  def self.down
    remove_column :offers, :response
  end
end
