class ImageUploadsController < ApplicationController
  #before_filter :authenticate_user!
  
  def create
    raise params.inspect
     @image_upload = ImageUpload.create(params[:image_upload])
     @image_upload.item_id = params[:item_id]
     
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
