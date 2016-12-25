class SessionPersistence
  attr_accessor :session, :lists

  def initialize(session)
    @session = session
    @lists = @session[:lists] ||= []
  end

  def fetch_list(id)
    lists[id.to_i]
  end

  def list_name(id)
    list = fetch_list(id)
    list[:name]
  end

  def all_lists
    lists
  end 

  def list_exists?(name)
    lists.values.any? { |list| list[:name].casecmp(name).zero? }
  end

  def update_list_name(list_id, new_name)
    list = fetch_list(list_id)
    list[:name] = new_name
  end

  def create_new_list(list_name)
    id = next_id(lists)
    lists[id] = { name: list_name, todos: {} }
  end

  def add_todo_to_a_list(list_id, todo)
    list = fetch_list(list_id)
    todos = list[:todos]

    todo_id = next_id(todos)
    todos[todo_id] = { name: todo, completed: false }
  end

  def update_todo_status(list_id, todo_id, status)
    list = fetch_list(list_id)
    list[:todos][todo_id][:completed] = status
  end

  def delete_todo_from_list(list_id, todo_id)
    list = fetch_list(list_id)
    list[:todos].delete(todo_id.to_i)
  end

  def mark_list_complete(id)
    list = fetch_list(id)
    todos = list[:todos].values

    todos.each { |todo| todo[:completed] = 'true' unless todo[:completed] }
  end

  def delete_list(id)
    deleted_list = lists.delete(id.to_i)
    deleted_list[:name]
  end

  private

  def next_id(list)
    (list.keys.max || 0) + 1
  end
end