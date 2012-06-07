ActiveAdmin.register Offer do
  config.clear_sidebar_sections!

  scope :all do |offer|
    offer.where("user_id == ?", current_user)
  end

  scope :pending, :default => true do |offer|
    offer.where("user_id == ? and response == ?", current_user, 0)
  end

  scope :accepted do |offer|
    offer.where("user_id == ? and response == ?", current_user, 1)
  end

  scope :sent do |offer|
    offer.where("sender_id == ? and response == ?", current_user, 0)
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
    
    column "Sender" do |offer|
      username = User.find(offer.sender_id).username
      link_to username, user_url(offer.sender_id)
    end

    column "Offer" do |offer|
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

    column "Wanted" do |offer|
      items = []
      offer.wanted_items.each do |wanted_item|
        items << link_to(image_tag((Product.find(wanted_item.product_id).image.url(:thumb)), :class => "offer_thumb" ), item_url(wanted_item.product_id))
      end
      items = items.uniq
      items.join(" + ").html_safe
    end
    
    column "Cash" do |offer|
      number_to_currency(offer.cash_value)
    end
    
    if params[:scope] != "sent"
      column "Response?" do |offer|
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
   
  # ===================================================================
  # controllers stuff
  # ===================================================================
  controller do
    helper :offers

    def make_offer      
      if params[:id]
        @offer = Offer.find(params[:id])
      else
        @offer = Offer.create :sender_id => current_user.id
      end
      
      if params[:accept]
        @offer.update_attribute(:response, "1")
        @offer.save!
        redirect_to offers_path
      elsif params[:name] == "counter_offer"
        @sender = @offer.sender
        @user = @offer.user
      elsif params[:name] == "new_offer"
        @sender = current_user
        @user = User.find(params[:receiver_id])
        @cart = Order.find(params[:cart])
        @offer.user_id = params[:receiver_id]
        @offer.save!
      end
    end
     
    def send_counter_offer
      if params[:name] == "new_offer"
        offer_id = params[:id]
        @offer = Offer.find(offer_id)
      else
        @offer = Offer.find_by_user_id(current_user.id)
      end
      
      # FOR OFFERING ITEMS
      offering_items = params[:wanted]
      offering_item_ids = offering_items.keys unless offering_items.blank?
      offering_items_ids ||= []

      # deletes all old records
      old_offer_items = OfferItem.find_all_by_offer_id(offer_id)
      # TODO CHECK IF NOTHING CHANGED THEN SKIP THE FOLLOWING STEPS
      old_offer_items.each { |item| item.destroy }
      # adds new records
      if !offering_item_ids.blank?
        offering_item_ids.each do |product_id|
          offer_item = OfferItem.new :offer_id => params[:id], :product_id => product_id
          offer_item.save!
        end
      end

      # FOR WANTED ITEMS
      wanted_items = params[:offering]
      wanted_item_ids = wanted_items.keys unless wanted_items.blank?
      wanted_item_ids ||= []

      wanted_id = params[:id]
      # deletes all old records
      old_wanted_items = WantedItem.find_all_by_offer_id(wanted_id)
      # TODO CHECK IF NOTHING CHANGED THEN SKIP THE FOLLOWING STEPS        
      old_wanted_items.each { |item| item.destroy }
      # adds new records
      if !wanted_item_ids.blank?
        wanted_item_ids.each do |product_id|
          wanted_item = WantedItem.new :offer_id => params[:id], :product_id => product_id
          wanted_item.save!
        end
      end

      # BARGAIN CASH
      offer_cash_value_hidden = params[:offer_cash_value_hidden]
      @offer.cash_value = offer_cash_value_hidden

      # SWAP SENDER AND USER
      user_id = @offer.user_id
      if params[:name] == "new_offer"
        sender_id = current_user.id
      else
        sender_id = @offer.sender_id
        @offer.user_id = sender_id
        @offer.sender_id = user_id
      end
      @offer.save!

      flash_mess = "You have sent the offer"
      respond_to do |format|
       flash[:success] = flash_mess
       format.html { redirect_to offers_path }
      end
    end
   
    def respond

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