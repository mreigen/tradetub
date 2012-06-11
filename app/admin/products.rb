ActiveAdmin.register Product, :as => "Item" do
  config.clear_sidebar_sections!
  
  after_build do |currm|
    currm.user_id = current_user
  end
  
  scope :all, :default => true do |ps|
    user_id = params[:user_id]
    user_id ||= current_user
    ps.where("user_id == ?", user_id)
  end
  scope :available do |products|
    products.where("available_on < ?", Date.today)
  end
  scope :drafts do |products|
    products.where("available_on > ?", Date.today)
  end
  scope :featured_products do |products|
    products.where(:featured => true)
  end

  index do
    column "Title", :sortable => :title do |product|
       a truncate(product.title), :href => item_path(product)
    end
    
    column "Image", :sortable => :title do |product|
      div do
        a :href => item_path(product) do
          image_tag(product.image.url(:thumb))
        end
      end
    end
    
    column "Price", :sortable => :price do |product|
      div do number_to_currency(product.price) end
    end
    
    column "Description" do |product|
      div do product.description end
    end
    
    if current_user.id.to_s == params[:user_id] || ( !params[:user_id] && current_user)
      input :value => "List new item", :type => :submit, :onclick => "javascript: document.location.href = '" + new_item_path + "'"
    end
  end

  show do |p|
    div {render :partial => "show_item", :locals => {:item => p, :user => current_user} }
=begin
    return unless p.available
      
    h3 p.title + " - " + number_to_currency(p.price)
    div p.description
    div image_tag(p.image.url(:medium))
    
    p.image_uploads.each do |iu|
      span image_tag(iu.image.url(:medium))
    end
    
    # category name
    
    case p.trade_type
      when 0
        div "both cash & trade"
      when 1
        div "cash only"
      when 2
        div "trade only"
    end
    
    active_admin_comments
            
    div link_to "Pick this", add_to_cart_path(p.id), :class => "button"    
=end
  end

=begin
  sidebar "Trader", :only => :show do
    @product = Product.find(params[:id]) unless params[:id].blank?
    @user = User.find(@product.user_id) unless @product.blank?
    render('/admin/sidebar_links', :user => @user)
  end
=end
 
  form :html => { :enctype => "multipart/form-data" } do |f|
     f.inputs "Details" do
      f.input :title
      f.input :image, :as => :file
      f.input :description
      f.input :price
      f.input :cat_id, :as => :select, :collection => Category.asc.map{|c| [c.fullname, c.nickname]}
      f.input :user_id, :value => f.template.current_user.name, :type => :hidden
    end
    f.buttons
   end
   
   # this is for multiple image uploading
   # need more work
   #form :partial => "image_upload"

   controller do
     helper :all
   end
end
