class ImageUpload < ActiveRecord::Base
  belongs_to :product
  
  has_attached_file :image, :styles => { :medium => "238x238>", :thumb => "100x100>" }
end
