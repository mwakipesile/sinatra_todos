require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'password1'
end

before do 
  session[:lists] ||= []
  @lists = session[:lists]
end

get '/' do
  redirect('/lists')
end

get '/lists' do
  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list, layout: :layout
end

post '/lists' do
  session[:lists] << { name: params['list_name'], todos: [] }
  redirect('/lists')
end
get '/lists/:id' do |id|
  @list_id = id.to_i
  erb :list, layout: :layout
end
