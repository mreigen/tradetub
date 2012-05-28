class CartController < ApplicationController

  #before_filter :login_required
  before_filter :find_cart

  def add
    @cart.save if @cart.new_record?
    session[:cart_id] = @cart.id
    product = Product.find(params[:id])
    unless LineItem.find_by_product_id(product)
      LineItem.create! :order => @cart, :product => product, :price => product.price
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
    #session.delete(:cart_id)
    flash[:notice] = "Thank you for your purchase! We will ship it shortly!"
    redirect_to new_offer_path
  end

  protected

  def find_cart
    @cart = session[:cart_id] ? Order.find(session[:cart_id]) : current_user.orders.build
  end

end
