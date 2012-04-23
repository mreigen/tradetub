ActiveAdmin.register Product, :as => "Item" do
  config.clear_sidebar_sections!
  
  after_build do |currm|
    currm.author = current_user
  end
  
  scope :all, :default => true do |ps|
    user_id = params[:user_id]
    user_id ||= current_user
    ps.where("author == ?", user_id)
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
  end

  show do |p|
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
        
    div link_to "Pick this", add_to_cart_path(p.id), :class => "button"
  end

  sidebar "Provider", :only => :show do
    @product = Product.find(params[:id]) unless params[:id].blank?
    @user = User.find(@product.author) unless @product.blank?
    render('/admin/sidebar_links', :user => @user)
  end

  form :html => { :enctype => "multipart/form-data" } do |f|
     f.inputs "Details" do
      f.input :title
      f.input :image, :as => :file
      f.input :description
      f.input :price
      f.input :cat_id
      f.input :author, :value => f.template.current_user
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
