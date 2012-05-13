require 'test_helper'

class ImageUploadsControllerTest < ActionController::TestCase
  setup do
    @image_upload = image_uploads(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:image_uploads)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create image_upload" do
    assert_difference('ImageUpload.count') do
      post :create, :image_upload => @image_upload.attributes
    end

    assert_redirected_to image_upload_path(assigns(:image_upload))
  end

  test "should show image_upload" do
    get :show, :id => @image_upload.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @image_upload.to_param
    assert_response :success
  end

  test "should update image_upload" do
    put :update, :id => @image_upload.to_param, :image_upload => @image_upload.attributes
    assert_redirected_to image_upload_path(assigns(:image_upload))
  end

  test "should destroy image_upload" do
    assert_difference('ImageUpload.count', -1) do
      delete :destroy, :id => @image_upload.to_param
    end

    assert_redirected_to image_uploads_path
  end
end
