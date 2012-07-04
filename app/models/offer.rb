class Offer < ActiveRecord::Base  
  belongs_to :user
  
  has_one :rating
  
  has_many :offer_items
  has_many :wanted_items
  has_many :offer_services
  has_many :wanted_services
  
  scope :accepted, where(:response => 1)
    
  def self.all_by_scope(scope, c_user)
    if scope == "sent"
      Offer.find_all_by_sender_id(c_user)
    elsif scope == "receive"
      Offer.find_all_by_user_id(c_user)
    elsif scope == "all"
      Offer.where("user_id = ? OR sender_id = ?", c_user, c_user)
    end
  end
  
  def sender
    User.find(self.sender_id)
  end
  
  def receiver
    User.find(self.user_id)
  end
end