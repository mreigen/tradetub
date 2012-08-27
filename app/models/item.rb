class Item < ActiveRecord::Base
  include ActionView::Helpers::TextHelper
  
  define_index do
    indexes title
    indexes description
  end
  
  belongs_to :user
  has_many :categories
  has_many :image_uploads, :dependent => :destroy
  
  attr_accessible :deleted, :available, :price, :title, :cat_id, :user_id, :description, :image, :trade_type, :image_uploads_attributes
  accepts_nested_attributes_for :image_uploads, :allow_destroy => true
  
  # Named Scopes
  scope :available, lambda{ where("available_on < ? AND deleted = 'f' AND available = 't'", Date.today) }
  scope :drafts, lambda{ where("available_on > ? AND deleted = 'f' AND available = 't'", Date.today) }
  scope :related, lambda { |c, i| where("cat_id = ? AND deleted = 'f' AND available = 't' AND id <> ?", c, i) }
  scope :other_items_by_user, lambda {|u, i| where("user_id = ? AND deleted = 'f' AND available = 't' AND id <> ?", u, i)}

  # Validations
  validates_presence_of :title
  validates_presence_of :price
  #validates_presence_of :image_file_name
  
  def get_main_image(size)
    (image_uploads[0].blank?) ? "/images/missing.jpg" : image_uploads[0].image.url(size.to_sym)
  end
  
  def get_image(index, size)
    (image_uploads[index].blank?) ? "/images/missing.jpg" : image_uploads[index].image.url(size.to_sym)
  end
  
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
    self.user_id == user.id
  end
  
  def in_trade?
    !WantedItem.find_by_item_id(self.id).nil? || !OfferItem.find_by_item_id(self.id).nil?
  end
  
  def get_description(max = nil)
    desc = self.description
    return desc if max.blank?
    truncate(desc, :length => max, :omission => "...")
  end
end
