class Api::V1::ItemsController < ApplicationController
  extend Parser
  
  caches_page :show
  caches_page :list
  
  def show
    @item = Item.find(params[:id])
    @user = User.find(@item.user_id)
    @ret = {}
    
    render :json => {:error => "missing url"}, :status => 500 and return if params[:url].blank?
    
    parse_options = {
      :user => @user,
      :link => params[:url]
    }
    case params[:source]
    when "ebay"
      parse_options[:source] = "ebay"
    when "cl"
      parse_options[:source] = "cl"
    when "oodle"
      parse_options[:source] = "oodle"
    when "etsy"
      parse_options[:source] = "etsy"
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
       
    @ret = Parser.parse_item(parse_options) if @ret.blank?
    
    if params[:key] == "123"
      render :status => 200, :json => @ret
    end
  end
  
  def test
    # scrape city codes
    city_codes = []
    city_names = []
    state_name = ""
    @ret = []
    
    doc = Nokogiri::HTML(open("http://www.craigslist.org/about/sites"))
    doc.css(".state_delimiter").children().each do |state|
      state_name = state.text
      state.parent.next_element.css("li a").children().each do |a|
        _ret = {:state => state_name}
        city_code = a.parent["href"]
        city_code = city_code.to_s.gsub(/\.craigslist\..*/, "").gsub(/http:\/\//, "")
        city_codes.push(city_code)
        _ret[:city_code] = city_code
        
        a = a.to_s
        if a.downcase != state_name.downcase
          a = a + ", " + state_name
        end
        city_names.push(a)
        _ret[:city] = a
        
        a = CGI.escape(a)
        url = URI.parse("http://maps.googleapis.com/maps/api/geocode/json?address=#{a}&sensor=false")
        
        res = Net::HTTP.get(url)
        parsed_json = ActiveSupport::JSON.decode(res)
        location_results = parsed_json["results"]
        _location = {}
        unless location_results.blank?
          location = location_results[0]["geometry"]["location"]
          lat = location["lat"]
          lng = location["lng"]
          _location = {:lat => lat, :lng => lng}
        end
        _ret[:location] = _location
        
        @ret.push(_ret)
      end
      
    end
    
    
    # find state by lat and long
    # http://maps.googleapis.com/maps/geo?q=37.714224,-112.961452&output=json&sensor=false
    
    render :json => @ret.to_json
  end
  
  def string_difference_percent
    a = params[:a]
    b = params[:b]
    
    longer = [a.size, b.size].max
    same = a.each_char.zip(b.each_char).select { |a,b| a == b }.size
    render :json => ((longer - same) / a.size.to_f).to_json
  end
  
  def list
    lat = params[:lat]
    lng = params[:lng]
    zip = params[:zip]
    query = params[:query] || ""
    query = CGI::escape(query)
    limit = params[:limit]
    
    # craigslist only
    sub_area = params[:sub_area] || ""
    page = params[:page]
    page = page.blank? ? 0 : page.to_i
    
    if !lat.blank? && !lng.blank?
      geo_query = "#{lat},#{lng}"
    elsif !zip.blank?
      geo_query = zip
    end
    
    @ret_array = []
    
    res = Geokit::Geocoders::GoogleGeocoder.reverse_geocode(geo_query)
    country_name_code = res.country
    state_code = res.state
    
    if !zip.blank?
      lat = res.lat
      lng = res.lng
    end
    
    parse_options = {
      :sub_area => "",
      :page => page,
      :limit => limit,
      :query => query,
      :lat => lat,
      :lng => lng,
      :zip => zip,
      :state_code => state_code,
      :country_name_code => country_name_code
    }
    case params[:source]
    when "ebay"
      parse_options[:source] = "ebay"
    when "cl"
      parse_options[:source] = "cl"
    when "oodle"
      parse_options[:source] = "oodle"
    when "etsy"
      parse_options[:source] = "etsy"
    end
    
    @ret_array = Parser::parse_item_list(parse_options)
    if params[:key] == "123"
      render :status => 200, :json => @ret_array
    end
  end
  
end