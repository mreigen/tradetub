class Product < ActiveRecord::Base
  
  belongs_to :user
  has_many :categories
  has_many :image_uploads
  
  attr_accessible :deleted, :available, :price, :title, :cat_id, :user_id, :description, :image
  
  # Named Scopes
  scope :available, lambda{ where("available_on < ? AND deleted = 'f' AND available = 't'", Date.today) }
  scope :drafts, lambda{ where("available_on > ? AND deleted = 'f' AND available = 't'", Date.today) }
  scope :related, lambda { |c, i| where("cat_id = ? AND deleted = 'f' AND available = 't' AND id <> ?", c, i) }
  scope :other_items_by_user, lambda {|u, i| where("user_id = ? AND deleted = 'f' AND available = 't' AND id <> ?", u, i)}

  # Validations
  validates_presence_of :title
  validates_presence_of :price
  #validates_presence_of :image_file_name
  
  has_attached_file :image, 
                    :styles => { :original=> "", :medium => "238x238#", :thumb => "100x100#" },
                    :processors => [:auto_orient, :thumbnail]
                    
  # return trade type in string
  def get_trade_type
    case trade_type
      when 0
        "accept trade and cash"
      when 1
        "cash only"
      when 2
        "trade only"
    end
  end
  
  def belongs_to?(user)
    false if user.blank?
    self.user_id == user.id.to_s
  end
  
  def in_trade?
    !WantedItem.find_by_product_id(self.id).nil? || !OfferItem.find_by_product_id(self.id).nil?
  end
end
