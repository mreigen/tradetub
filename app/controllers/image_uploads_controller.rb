class ImageUploadsController < InheritedResources::Base
  #before_filter :authenticate_user!
  
  def create
     @image_upload = ImageUpload.create(params[:image_upload])
     @image_upload.product_id = params[:product_id]
     
     if @image_upload.save
       render :json => [{ :pic_path => @image_upload.image.url.to_s , :name => @image_upload.image.instance.attributes["image_file_name"] }], :content_type => 'text/html'
     else
       render :json => { :result => 'error'}, :content_type => 'text/html'
     end
   end
   
   def show
     @image_uploads = ImageUpload.find(params[:image_upload])
   end
   
   def update
   end
end
