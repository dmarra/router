require 'sinatra/base'
require 'tilt/erb'
require 'rest-client'
require 'csv'
require 'gistance'

# get all campaign offices
CAMPAIGN_CSV = RestClient.get('http://d2bq2yf31lju3q.cloudfront.net/d/campaign-offices.csv')
ALL_OFFICES = CSV.new(CAMPAIGN_CSV, headers: true, header_converters: :symbol)
ALL_OFFICES = ALL_OFFICES.to_a.map {|row| row.to_hash }.freeze

class Router < Sinatra::Base
  Gistance.configure do |c|
    c.units = 'imperial'
  end

  configure do
    set :views, './views'
  end

  get '/' do
    # get current location
    @current_location = RestClient.get('http://geoip.nekudo.com/api/')
    @current_location = JSON.parse(@current_location)['location']

    # get campaign office distance
    @all_offices = ALL_OFFICES.dup
    @all_offices.each do |office|
      distance_matrix = Gistance.distance_matrix(
        destinations: ["#{@current_location['latitude']},#{@current_location['longitude']}"],
        origins: ["#{office[:lat]},#{office[:lon]}"]
      )
      office[:distance_int] = distance_matrix['rows'][0]['elements'][0]['distance']['value']
      office[:distance_text] = distance_matrix['rows'][0]['elements'][0]['distance']['text']
    end

    # sort by closest
    @all_offices.sort_by! { |v| v[:distance_int].to_i }
    @nearest_campaign = @all_offices.first

    erb :index
  end

  get '/get/:zip' do
    zip = params[:zip]
    url = "https://go.berniesanders.com/page/event/search_results?orderby=zip_radius&zip_radius%5b0%5d=#{zip}&zip_radius%5b1%5d=60&country=US&radius_unit=mi&name=carpool&format=json"
    @all_carpools = JSON.parse(RestClient.get(url))
    @all_carpools['results'].sort_by! { |v| v['distance'].to_i }
    erb :get
  end
end
