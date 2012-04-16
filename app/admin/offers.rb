ActiveAdmin.register Offer do
  
  scope :all, :default => true do |offer|
    offer.where("user_id == ?", current_user)
  end
  
  index do
    column "Sender" do |offer|
      username = User.find(offer.sender_id).username
      link_to username, admin_user_url(offer.sender_id)
    end

    column "is offering you" do |offer|
      items = []
      OfferItem.find_all_by_offer_id(offer.id).each do |offer_item|
        items << link_to(image_tag((Product.find(offer_item.product_id).image.url(:thumb)) ), admin_item_url(offer_item.product_id))
      end
      items.join(" + ").html_safe
    end

    column "for your item" do |offer|
      items = []
      OfferItem.find_all_by_offer_id(offer.id).each do |offer_item|
        items << link_to(image_tag((Product.find(offer_item.product_wanted_id).image.url(:thumb)) ), admin_item_url(offer_item.product_wanted_id))
      end
      items = items.uniq
      items.join(" + ").html_safe
    end
    
    default_actions
   end
   
   form do |f|
     f.inputs "Admin Details" do
       f.input :sender_id
     end
     f.buttons
   end
  
   #after_create { |admin| admin.send_reset_password_instructions }

   def password_required?
     new_record? ? false : super
   end
end
