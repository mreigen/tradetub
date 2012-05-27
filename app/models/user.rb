class User < ActiveRecord::Base
  has_many :products
  has_many :orders
  has_many :ratings
  has_many :offers
  has_many :services
  
  has_attached_file :image, :styles => { :medium => "300x300>", :thumb => "100x100>" }
    
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :trackable, :validatable
  # To login with providers (facebook, twitter...)
  devise :omniauthable
  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :facebook_avatar, :username, :last_name, :first_name, :gender, :location

  def just_created?
    just_created
  end
  
  def get_image
    if !image_file_name.blank? # if there is image uploaded with paperclip
      image.url
    elsif !facebook_avatar.blank?
      facebook_avatar
    else
      "images/no-avatar.png"
    end
  end
  
  def name
    first_name + " " + last_name
  end
  
  def self.find_for_facebook_oauth(access_token, signed_in_resource=nil)
    data = access_token.extra.raw_info
    if user = self.find_by_email(data.email)
      #user.username = data.username
      #user.facebook_avatar = access_token.info.image
      user
    else # Create a user with a stub password. 
      self.create(:just_created => true, :email => data.email, :password => Devise.friendly_token[0,20], :facebook_avatar => access_token.info.image, :first_name => data.first_name, :last_name => data.last_name, :username => data.username, :gender => data.gender) 
    end
  end
  
  def self.new_with_session(params, session)
     super.tap do |user|
       if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
         user.email = data["email"]
       end
     end
   end
   
end
