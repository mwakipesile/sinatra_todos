require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'password1'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
  @lists = session[:lists]
  @flash_message_keys = [:error, :success]
end

helpers do
  def load_list(id)
    list = @lists[id.to_i]
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
    elsif @lists.any? { |list| list[:name].casecmp(name).zero? }
      return 'Name taken'
    end
  end

  def invalid_todo_name(name)
    if !(1..100).cover?(name.size)
      return 'Todo name must be between 1 and 100 characters'
    end
  end

  def list_completed?(list)
    list[:todos].all? { |todo| todo[:completed] }
  end

  def list_class(list)
    return 'new' if list[:todos].size.zero?
    list_completed?(list) ? 'complete' : '' 
  end

  def todo_class(todo)
    todo[:completed] ? 'complete' : ''
  end

  def todos_count(list)
    list[:todos].size
  end

  def remaining_todos_count(list)
    list[:todos].count { |todo| !todo[:completed] } 
  end

  # Sort lists: uses implicitly passed in block & partition method
  def sort(lists)
    complete, incomplete = lists.partition { |list| list_completed?(list)}
    
    incomplete.each { |list| yield list, lists.index(list) }
    complete.each { |list| yield list, lists.index(list) }
  end

  # Sort todos: uses explicitly passed in block
  def sort_todos(list, &block)
    complete_todos = {}
    incomplete_todos = {}

    list[:todos].each_with_index do |todo, id|
      if todo[:completed]
        complete_todos[todo] = id
      else
        incomplete_todos[todo] = id
      end
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
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
  @list = load_list(id)
  erb :list, layout: :layout
end

post '/lists/:id' do |id|
  @list_id = id.to_i
  @list = load_list(id)

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
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

post '/lists/:id/delete' do |id|
  list_name = load_list(id)[:name]

  @lists.delete_at(id.to_i)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "#{list_name} list has been deleted!"
    redirect "/lists"
  end
end

post '/lists/:id/todos' do |id|
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

post '/lists/:id/todos/:todo_id' do |id, todo_id|
  is_completed = params[:completed] == 'true'
  @list_id = id.to_i
  @todo_id = todo_id.to_i

  @list = load_list(id)
  @list[:todos][@todo_id][:completed] = is_completed

  session[:success] = "#{@list[:name]} list has been updated"
  redirect("/lists/#{id}")
end

post '/lists/:id/todos/:todo_id/delete' do |id, todo_id|
  @list_id = id.to_i
  @todo_id = todo_id.to_i

  @list = load_list(id)
  todo = @list[:todos].delete_at(@todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "#{todo[:name]} has been deleted from this list"
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:id/completed' do |id|
  @list_id = id.to_i
  @list = load_list(id)

  complete_all = @list[:todos].any? { |todo| !todo[:completed] }
  @list[:todos].each { |todo| todo[:completed] = complete_all }

  session[:success] = "#{@list[:name]} list has been updated"
  redirect("/lists/#{id}")
end
