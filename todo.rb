require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'password1'
end

before do 
  session[:lists] ||= []
  @lists = session[:lists]
  @flash_message_keys = [:error, :success]
end

helpers do
  def invalid_name_message(name)
    if !(1..100).cover?(name.strip.size) 
      return 'Name must be between 1 and 100 characters'
    elsif @lists.detect { |list| list[:name].downcase == name.downcase }
      return 'Name taken'
    end
  end
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
  error = invalid_name_message(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "#{list_name} list created!"
    redirect('/lists')
  end
end

get '/lists/:id' do |id|
  @list_id = id.to_i
  erb :list, layout: :layout
end
