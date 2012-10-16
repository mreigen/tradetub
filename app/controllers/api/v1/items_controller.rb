class Api::V1::ItemsController < ApplicationController
  def show
    @item = Item.find(params[:id])
    @user = User.find(@item.user_id)
    @ret = {}
    
    render :json => {:error => "missing url"}, :status => 500 and return if params[:url].blank?
    link = params[:url]
    
    case params[:source]
    when "ebay"
      @ret = {}
    when "cl"
      options = {
        :user => @user,
        :link => link
      }
      get_cl_info(options)
    when "oodle"
      @ret = {}
    when "etsy"
      @ret = {}
    else
      # our items are priority
      @ret = {
        :id => @item.id,
        :title => @item.title,
        :description => @item.description,
        :image => @item.image_uploads.first.image.url,
        :price => @item.price,
        :cat_id => @item.cat_id,
        :link => nil,
        :lat => nil,
        :long => nil,
        :zip => nil,
        :posted_at => @item.created_at,
        :user_id => @user.id,
        :phone => nil,
        :email => @user.email,
        :text => nil
      }
    end
    
    if params[:key] == "123"
      render :status => 200, :json => @ret
    end
  end
  
  def list
    @all_item = Item.all
    @ret_array = []
    
    case params[:source]
    when "ebay"
      @ret_array.push({})
    when "cl"  
      feed = Feedzirra::Feed.fetch_and_parse("http://sfbay.craigslist.org/search/sss/sby?query=scooter&minAsk=&maxAsk=&hasPic=1&format=rss")
      
      feed.entries.each do |e|
        url = e.url
        #doc = Nokogiri::HTML(open(url.to_s))
        # see if this posting "has been flagged for removal"
        #next if (/has been flagged for removal/.match(doc.at_css("#userbody")))
        
        # main image
        #image_tag = doc.at_css("div.iw img")
        #image = image_tag.blank? ? "" : image_tag["src"]
        
        # phone number
        #text_body = doc.css("#userbody").text
        #phone = /\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})/.match(text_body)
        
        @ret_array.push({
          :title => e.title,
          :description => e.summary,
          #:image => image,
          :posted_at => e.published,
          :url => e.url,
          :source => "cl"
        })
      end
      
    when "oodle"
      @ret_array.push({})
    when "etsy"
      @ret_array.push({})
    end
    
    if params[:key] == "123"
      render :status => 200, :json => @ret_array
    end
  end
  
  def get_cl_info(options)
    user = options[:user]
    link = options[:link]
    
    doc = Nokogiri::HTML(open(link))
    # see if this posting "has been flagged for removal"
    render :json => {:error => "item has been removed"}, :status => 500 and return if (/has been flagged for removal/.match(doc.at_css("#userbody")))
    
    # scrape title
    title = doc.at_css("body h2").text
    
    # scrape description
    description = ""
    doc.css("#userbody").children().each do |child|
      description += child.text if child.type() == 3
    end
    
    # scrape price
    price = /\$[\d]+/.match(title).to_s
    price ||= /\$[\d]+/.match(description).to_s
    price.gsub!(/\$/,"")
    
    # scrape posted time
    posted_at_tag = doc.at_css(".postingdate")
    posted_at = posted_at_tag.blank? ? nil : posted_at_tag.text.to_datetime
    
    # main image
    image_tag = doc.at_css("div.iw img")
    image = image_tag.blank? ? nil : image_tag["src"]
    
    # scrape email
    email_tag = doc.at_css("a[href ^= 'mailto']")
    email = email_tag["href"].gsub!("mailto:","").to_s unless email_tag.blank?
    
    # phone number
    phone = /\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})/.match(description).to_s
    phone.gsub!(/[-. ]/, "")
    
    @ret = {
      :id => nil,
      :title => title,
      :description => description,
      :image => image,
      :price => price,
      :lat => nil,
      :long => nil,
      :zip => nil,
      :posted_at => posted_at,
      :user_id => user.id,
      :phone => phone,
      :email => email,
      :text => phone
    }
  end
  
end