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
  session[:lists] ||= {}
  @lists = session[:lists]
  @flash_message_keys = [:error, :success]
end

helpers do
  def next_id(list)
    max_id = list.keys.max || 0
    max_id + 1
  end

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
    elsif @lists.values.any? { |list| list[:name].casecmp(name).zero? }
      return 'Name taken'
    end
  end

  def invalid_todo_name(name)
    if !(1..100).cover?(name.size)
      return 'Todo name must be between 1 and 100 characters'
    end
  end

  def list_completed?(todos) 
    !todos.empty? && todos.values.all? { |todo| todo[:completed] }
  end

  def list_class(list)
    todos = list[:todos]
    return 'new' if todos.size.zero?
    list_completed?(todos) ? 'complete' : '' 
  end

  def todo_class(todo)
    todo[:completed] ? 'complete' : ''
  end

  def todos_count(list)
    list[:todos].size
  end

  def remaining_todos_count(list)
    list[:todos].values.count { |todo| !todo[:completed] } 
  end

  # Sort lists: uses implicitly passed in block & partition method
  def sort(lists)
    completed, incomplete = lists.keys.partition { |id| list_completed?(lists[id][:todos])}
    incomplete.each { |id| yield id, lists[id] }
    completed.each { |id| yield id, lists[id] }
  end

  # Sort todos: uses explicitly passed in block
  def sort_todos(todos, &block)
    completed_todos = {}
    incomplete_todos = {}

    todos.each do |id, todo|
      if todo[:completed]
        completed_todos[id] = todo
      else
        incomplete_todos [id] = todo
      end
    end

    incomplete_todos.each(&block)
    completed_todos.each(&block)
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
    list_id = next_id(@lists)
    session[:lists][list_id] = { name: list_name, todos: {} }
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

  @lists.delete(id.to_i)
  
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
  todos = @list[:todos]

  if error
    session[:error] = error
  else
    todo_id = next_id(todos)
    todos[todo_id] = { name: todo, completed: false }
    session[:success] = "#{todo} has been added to the list!"
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
  todo = @list[:todos].delete(@todo_id)

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
  # binding.pry
  todos = @list[:todos].values

  complete_all = todos.any? { |todo| !todo[:completed] }
  todos.each { |todo| todo[:completed] = complete_all }

  session[:success] = "#{@list[:name]} list has been updated"
  redirect("/lists/#{id}")
end
