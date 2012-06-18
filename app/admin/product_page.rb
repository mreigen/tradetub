ActiveAdmin.register_page "Product Page" do
  menu false

  content do
    products = Product.where("deleted == 'f' AND available == 't'")
    render :partial => "products/index", :locals => {:products => products}
  end
end