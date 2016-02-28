require 'sinatra/base'

class Router < Sinatra::Base
  configure do
    set :views, './views'
  end

  get '/' do
    erb :index
  end
end
