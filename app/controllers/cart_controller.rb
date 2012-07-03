class CartController < ApplicationController
  before_filter :authenticate_user!
  #before_filter :login_required
  before_filter :find_cart

  def add
    @cart.save if @cart.new_record?
    session[:cart_id] = @cart.id
    item = Item.find(params[:id])
    unless LineItem.find_by_item_id(item)
      LineItem.create! :order => @cart, :item => item, :price => item.price
      @cart.recalculate_price!
      flash[:notice] = "Item added to cart!"
      redirect_to '/cart'
    else
      flash[:notice] = "Item is already in your cart"
      redirect_to request.referer
    end
  end

  def remove
    item = @cart.line_items.find(params[:id])
    item.destroy
    @cart.recalculate_price!
    flash[:notice] = "Item removed from cart"
    redirect_to '/cart'
  end

  def checkout
    @cart.checkout!
    session.delete(:cart_id)
    flash[:notice] = "Your item(s) have been added to the offer page! Please make an offer to start trading!!"
    receiver_id = Item.find(@cart.line_items.first().item_id).user_id
    # TO DO: multiple receivers
    redirect_to make_offer_path :receiver_id => receiver_id, :name => "new_offer", :cart => @cart
  end

  protected

  def find_cart
    @cart = session[:cart_id] ? Order.find(session[:cart_id]) : current_user.orders.build
  end

end
