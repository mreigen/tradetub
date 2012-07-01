class ImageUpload < ActiveRecord::Base
  belongs_to :item
  attr_accessor :delete_image
  attr_accessible :image
  has_attached_file :image, 
=begin #production
    :storage => :s3,
    :bucket => ENV['S3_BUCKET_NAME'],
    :s3_credentials => {
      :access_key_id => ENV['AWS_ACCESS_KEY_ID'],
      :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
    },
=end
    :styles => { :large => "520x380>", :medium => "238x238#", :thumb => "100x100#" }
  
  before_validation { :image.clear if delete_image == '1'}
end
