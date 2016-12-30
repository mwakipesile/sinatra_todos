require 'pry'
require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require_relative 'models/database_persistence'

configure(:development) do
  require 'sinatra/reloader'
  also_reload './models/database_persistence.rb'
end


configure do
  enable :sessions
  set :session_secret, 'password1'
  set :erb, :escape_html => true
end

before do
  @storage = DatabasePersistence.new(logger)
  @flash_message_keys = [:error, :success]
end

before(%r{/lists\/(\d+)}) { |id| @list_id = id.to_i }

before(%r{/lists\/\d+\/todos\/(\d+)}) { |id| @todo_id = id.to_i }

helpers do
  def load_list(id)
    list = @storage.fetch_list(id.to_i)
    return list if valid_id?(id) && list

    session[:error] = '404. List with that ID doesn\'t exits.'
    redirect('/lists')
  end

  def valid_id?(id)
    return true if id.is_a?(Integer)
    id.to_i.to_s == id
  end

  def invalid_list_name_message(name)
    if !(1..100).cover?(name.size)
      return 'Name must be between 1 and 100 characters'
    #elsif @lists.values.any? { |list| list[:name].casecmp(name).zero? }
    elsif @storage.list_exists?(name)
      return 'Name taken'
    end
  end

  def slice_string!(str, limit = 100)
    str.sub!(str[limit..-1], '...')
  end

  def invalid_todo_name(name)
    if !(1..100).cover?(name.size)
      return 'Todo name must be between 1 and 100 characters'
    end
  end

  def list_completed?(list)
    list[:todos_count] > 0 && list[:remaining_todos_count].zero?
  end

  def list_class(list)
    return 'new' if list[:todos_count].zero?
    list_completed?(list) ? 'complete' : ''
  end

  def todo_class(todo)
    todo[:completed] ? 'complete' : ''
  end

  # Sort lists: uses implicitly passed in block & partition method
  def sort(lists)
    completed, incomplete = lists.partition { |list| list_completed?(list)}
    incomplete.each { |list| yield list }
    completed.each { |list| yield list }
  end

  # Sort todos: uses explicitly passed in block
  def sort_todos(todos, &block)
    completed, incomplete = todos.partition { |todo| todo[:completed] }
    incomplete.each(&block)
    completed.each(&block)
  end
end

get('/') { redirect('/lists') }

# View a list of all lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get('/lists/create') { erb :new_list, layout: :layout }

# Create a new list
post '/lists/create' do
  @name = params['list_name'].strip
  error = invalid_list_name_message(@name)

  if error
    session[:error] = error
    slice_string!(@name) if @name.size > 100
    halt erb(:new_list, layout: :layout)
  end

  @storage.create_new_list(@name)

  session[:success] = "#{@name} list created!"
  redirect('/lists')
end

get '/lists/:id' do
  @list = load_list(@list_id)
  @todos = @storage.fetch_todos(@list_id)
  erb :list, layout: :layout
end

get '/lists/:id/edit' do
  @list_name = @storage.list_name(@list_id)
  erb :edit_list, layout: :layout
end

post '/lists/:id/update' do
  @updated_name = params[:updated_name].strip
  error = invalid_list_name_message(@updated_name)

  if error
    @list_name = params[:old_name]
    session[:error] = error
    slice_string!(@updated_name) if @updated_name.size > 100
    halt erb(:edit_list, layout: :layout)
  end

  @storage.update_list_name(@list_id, @updated_name)
  session[:success] = "List name has been updated!"
  redirect("/lists/#{@list_id}")
end

post '/lists/:id/delete' do
  name = @storage.delete_list(@list_id)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "#{name} list has been deleted!"
    redirect "/lists"
  end
end

post '/lists/:id/todos' do
  todo = params[:todo].strip
  error = invalid_todo_name(todo)

  if error
    session[:error] = error
  else
    @storage.add_todo_to_a_list(@list_id, todo)
    session[:success] = "#{todo} has been added to the list!"
  end

  redirect("/lists/#{@list_id}")
end

post '/lists/:id/todos/:todo_id/update' do
  status = params[:completed] == 'true'
  @storage.update_todo_status(@list_id, @todo_id, status)

  session[:success] = "#{params[:list_name]} list has been updated"
  redirect("/lists/#{@list_id}")
end

post '/lists/:id/todos/:todo_id/delete' do
  todo = @storage.delete_todo_from_list(@list_id, @todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "#{params[:todo_name]} has been deleted from this list"
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:id/completed' do
  @storage.mark_all_todos_complete(@list_id)

  session[:success] = "#{params[:list_name]} list has been updated"
  redirect("/lists/#{@list_id}")
end
