class Offer < ActiveRecord::Base
  belongs_to :user
  
  has_one :rating
  
  has_many :offer_items
  has_many :wanted_items
  has_many :offer_services
  has_many :wanted_services
  
  scope :accepted, where(:response => 1)
end