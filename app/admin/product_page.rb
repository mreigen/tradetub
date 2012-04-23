ActiveAdmin.register_page "Product Page" do
  menu false

  content do
    products = Product.all
    render :partial => "products/index", :locals => {:products => products}
  end
end