class OffersController < ApplicationController
  before_filter :authenticate_user!
  helper :offers
  
  def update
  end
  
  def show
  end
  
  def create
  end
  
  def index
    @scopes = ['all', 'sent', 'received']
    unless params[:commit].blank?
      @offers = Offer.all_by_scope(params[:commit], current_user)
    else
      @offers = Offer.all_by_scope('all', current_user)
    end
  end
  
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
    offer_id = params[:id]
    
    if params[:name] == "new_offer"
      @offer = Offer.find(offer_id)
    else
      @offer = Offer.find_by_user_id(current_user.id)
    end
    
    session.delete(:cart_id)
    
    # FOR OFFERING ITEMS
    offering_items = params[:offering]
    offering_item_ids = offering_items.keys unless offering_items.blank?
    offering_items_ids ||= []

    # deletes all old records
    old_offer_items = OfferItem.find_all_by_offer_id(offer_id)
    # TODO CHECK IF NOTHING CHANGED THEN SKIP THE FOLLOWING STEPS
    old_offer_items.each { |item| item.destroy }
    # adds new records
    if !offering_item_ids.blank?
      offering_item_ids.each do |item_id|
        offer_item = OfferItem.new :offer_id => params[:id], :item_id => item_id
        offer_item.save!
      end
    end

    # FOR WANTED ITEMS
    wanted_items = params[:wanted]
    wanted_item_ids = wanted_items.keys unless wanted_items.blank?
    wanted_item_ids ||= []

    wanted_id = params[:id]
    # deletes all old records
    old_wanted_items = WantedItem.find_all_by_offer_id(wanted_id)
    # TODO CHECK IF NOTHING CHANGED THEN SKIP THE FOLLOWING STEPS        
    old_wanted_items.each { |item| item.destroy }
    # adds new records
    if !wanted_item_ids.blank?
      wanted_item_ids.each do |item_id|
        wanted_item = WantedItem.new :offer_id => params[:id], :item_id => item_id
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