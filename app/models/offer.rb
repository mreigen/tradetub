class Offer < ActiveRecord::Base
  belongs_to :user
  
  has_many :offer_items
end