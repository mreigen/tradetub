class ItemsController < ApplicationController
  before_filter :authenticate_user!, :except => [:show, :index, :front_page]
  helper :all
  
  def index
    if params[:search].blank?
      @items = Item.where("user_id = ?", current_user)
    else
      @items = Item.search params[:search]
    end
  end
  
  def front_page
    @items = Item.all
  end
  
  def new
    @item = Item.new
    5.times { @item.image_uploads.build }
  end
  
  def create
    @item = Item.new(params[:item])
    if @item.save
      flash[:notice] = "Item successfully created."
      redirect_to @item
    else
      render :action => "new"
    end
  end
  
  def show
    @item = Item.find(params[:id])
    @user = User.find(@item.user_id)
  end
  
  def edit
    @item = Item.find(params[:id])
    count = @item.image_uploads.count
    (5 - count).times { @item.image_uploads.build }
  end
  
  def update
    @item = Item.find(params[:id])
    @item.update_attributes(params[:item])
    if @item.save
      flash[:notice] = "Item successfully updated"
      redirect_to item_path
    else
      render :action => "edit"
    end
  end
  
  def set_visibility
    # check if user is logged in
    # check if the item belongs to current user and if the value is not blank
    @item = Item.find(params[:id])
    if @item.user_id == current_user.id || params[:value].blank?
      flash[:error] = "Sorry but you can't just put someone else's item off shelf, go but it!!"
    else
      # set visibility
      @item.toggle!(:available)
      @item.save
      flash[:notice] = "Your item has been taken off shelf"
    end
    redirect_to :back
  end

  def delete
    # check if user is logged in
    # check if the item belongs to current user and if the value is not blank
    @item = Item.find(params[:id])
    if @item.user_id != current_user.id
      flash[:error] = "Sorry but you can't just delete someone else's item!!"
    else
      if @item.in_trade?
        # set deleted to true
        @item.deleted = true
        @item.save
        flash[:notice] = "Your item has been deleted! We have informed your trading partner(s) who were interested in this item."
        redirect_to :back
      else
        @item.destroy
        flash[:notice] = "Your item has been permanently deleted!"
        redirect_to items_path
      end
      unless @item.errors.blank?
       flash[:error] = "Ooops, something went wrong, your item hasn't been changed"
      end
    end
    redirect_to :back
    rescue AbstractController::DoubleRenderError
      Rails.logger.info ""
  end
end
