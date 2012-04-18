ActiveAdmin.register Product, :as => "Item" do
  
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
       a truncate(product.title), :href => admin_item_path(product)
    end
    
    column "Image", :sortable => :title do |product|
      div do
        a :href => admin_item_path(product) do
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
    h3 p.title + " - " + number_to_currency(p.price)
    div p.description
    div image_tag(p.image.url(:medium))
    
    p.image_uploads.each do |iu|
      span image_tag(iu.image.url(:medium))
    end
    
    div p.author
  end
  
  sidebar :product_stats, :only => :show do
    attributes_table_for resource do
      row("Total Sold")  { Order.find_with_product(resource).count }
      row("Dollar Value"){ number_to_currency LineItem.where(:product_id => resource.id).sum(:price) }
    end
  end

  sidebar :recent_orders, :only => :show do
    Order.find_with_product(resource).limit(5).collect do |order|
      auto_link(order)
    end.join(content_tag("br")).html_safe
  end

  sidebar "Active Admin Demo" do
    render('/admin/sidebar_links', :model => 'products')
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

end
