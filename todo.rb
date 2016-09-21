require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
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
  def invalid_list_name_message(name)
    if !(1..100).cover?(name.size)
      return 'Name must be between 1 and 100 characters'
    elsif @lists.any? { |list| list[:name].casecmp(name).zero? }
      return 'Name taken'
    end
  end

  def invalid_todo_name(name)
    if !(1..100).cover?(name.size)
      return 'Todo name must be between 1 and 100 characters'
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
  list_name = params['list_name'].strip
  error = invalid_list_name_message(list_name)

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
  @list = @lists[@list_id]
  erb :list, layout: :layout
end

post '/lists/:id' do |id|
  @list_id = id.to_i
  @list = @lists[@list_id]

  @updated_name = params[:list_name].strip
  error = invalid_list_name_message(@updated_name)

  if error
    session[:error] = error
    @updated_name.sub!(@updated_name[100..-1], '...') if @updated_name.size > 0
    erb :edit_list, layout: :layout
  else
    @list[:name] = @updated_name
    session[:success] = "List name has been updated!"

    redirect("/lists/#{id}")
  end
end

get '/lists/:id/edit' do |id|
  @list_id = id.to_i
  @list = @lists[@list_id]
  erb :edit_list, layout: :layout
end

post '/lists/:id/delete' do |id|
  list_id = id.to_i
  list_name = @lists[list_id][:name]

  @lists.delete_at(list_id)
  session[:success] = "#{list_name} list has been deleted!"

  redirect('/lists')
end

post '/lists/:id/add' do |id|
  todo = params[:todo].strip
  error = invalid_todo_name(todo)
  @list = @lists[id.to_i]

  if error
    session[:error] = error
  else
    @list[:todos] << {name: todo, completed: false }
    session[:success] = "#{params[:todo]} has been added to the list!"
  end

  redirect("/lists/#{id}")
end
