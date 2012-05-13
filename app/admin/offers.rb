ActiveAdmin.register Offer do
  config.clear_sidebar_sections!

  scope :all, :default => true do |offer|
    offer.where("user_id == ?", current_user)
  end
  
  scope :rejected do |offer|
    offer.where("user_id == ? and response == ?", current_user, 2)
  end
  
  scope :accepted do |offer|
    offer.where("user_id == ? and response == ?", current_user, 1)
  end
  
  index do
    column "Status" do |offer|
      case offer.response
        when 0
          "New"
        when 1
          "Accepted"
        when 2
          "Rejected"
        when 3
          "Counter-offered"
      end
    end
    
    column "Member" do |offer|
      username = User.find(offer.sender_id).username
      link_to username, user_url(offer.sender_id)
    end

    column "Is offering you" do |offer|
      items = []
      offer.offer_items.each do |offer_item|
        items << link_to(image_tag((Product.find(offer_item.product_id).image.url(:thumb)), :class => "offer_thumb" ), item_url(offer_item.product_id))
      end
      
      if items.empty?
        "nothing"
      else
        items.join(" + ").html_safe
      end
    end

    column "For your item(s)" do |offer|
      items = []
      offer.wanted_items.each do |wanted_item|
        items << link_to(image_tag((Product.find(wanted_item.product_id).image.url(:thumb)), :class => "offer_thumb" ), item_url(wanted_item.product_id))
      end
      items = items.uniq
      items.join(" + ").html_safe
    end
    
    column "With cash value" do |offer|
      number_to_currency(offer.cash_value)
    end
    
    column "Your response" do |offer|
      links = []
      unless offer.response == 1
        links << link_to("Accept", offer_path(offer.id) + "/respond/accept", :confirm => "Accept this offer?", :method => :put)
      else
        links << content_tag(:label, "Accepted", :class => "unclickable")
      end
=begin No Reject option for now
      unless offer.response == 2
        links << link_to("Reject", offer_path(offer.id) + "/respond/reject", :confirm => "Reject this offer?", :method => :put)
      else
        links << content_tag(:label, "Rejected", :class => "unclickable")
      end
=end      
      unless offer.response == 1
        links << link_to("Counter Offer", "#")
      else
        links << content_tag(:label, "Counter Offer", :class => "unclickable")
      end
      
      links << link_to("View", offer_path(offer.id))
      links.join(" | ").html_safe
    end
   end
   
   
   show do |offer|
     render :partial => "view_offer_details", :locals => {:offer => offer, :user => current_user, :sender => User.find(offer.sender_id) }
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
   
   
   # controllers stuff
   controller do
     helper :offers
     
     def counter_offer
       if params[:accept]
         redirect_to "http://google.com"
       elsif params[:counter_offer]
         @offer = Offer.find(params[:id])
         @sender = @offer.sender
         @user = @offer.user
#         redirect_to counter_offer_path
       end
     end
     
     def respond
       @offer = Offer.find(params[:id])
       @respond = params[:respond]
       @offer.update_attributes(:response => respond_to_num(@respond))
       
       flash_mess = ""
       case @respond
        when "accept"
          flash_mess = "You have accepted the offer"
        when "reject"
          flash_mess = "You have rejected the offer"
        when "counter-offer"
          flash_mess = "You have counter-offered the offer"
       end
       
       respond_to do |format|
         flash[:success] = flash_mess
         format.html { redirect_to request.referer }
       end
     end

     private
     
     def respond_to_num(resp)
      ret = 0
      case resp
       when "accept"
         ret = 1
       when "reject"
         ret = 2
       when "counter-offer"
         ret = 3
      end
      ret
     end
     
   end
end
