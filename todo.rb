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

# View a list of all lists
get '/lists' do
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new list
post '/lists' do
  list_name = params['list_name']
  session[:lists] << { name: list_name, todos: [] }
  session[:success] = "#{list_name} list created!"
  redirect('/lists')
end

get '/lists/:id' do |id|
  @list_id = id.to_i
  erb :list, layout: :layout
end
