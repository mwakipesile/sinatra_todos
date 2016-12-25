require 'pg'

class DatabasePersistence
  attr_accessor :connection, :logger

  def initialize(logger)
    @connection = PG.connect(dbname: 'todos', password: 'Collapse2')
    @logger = logger
  end

  def fetch_list(id)
    name = list_name(id)
    return unless name

    { name: name, todos: fetch_todos(id) }
  end

  def fetch_todos(list_id)
    query = 'SELECT id, name, completed FROM todos WHERE list_id = $1'
    tuples = exec_todos(query, list_id)

    tuples.each_with_object({}) do |tuple, todos|
      status = tuple['completed'] == 't'
      todos[tuple['id'].to_i] = { name: tuple['name'], completed: status }
    end
  end
    
  def list_name(id)
    list = exec_todos('SELECT name FROM lists WHERE id = $1', id)
    return if list.ntuples.zero?

    list.first['name']
  end

  def all_lists
    query = <<-Q
      SELECT l.id, l.name, t.id AS todo_id, t.completed
      FROM lists AS l LEFT JOIN todos AS t ON l.id = t.list_id;
      Q
   
    tuples = exec_todos(query)

    tuples.each_with_object({}) do |tuple, lists|
      id = tuple['id'].to_i
      name = tuple['name']
      todo_id = tuple['todo_id']
      status = tuple['completed'] == 't'

      if lists[id]
        lists[id][:todos][todo_id] = {completed: status}
      else
        lists[id] = { name: name, todos: {}}
        lists[id][:todos][todo_id.to_i] = {completed: status} if todo_id
      end
    end
  end 

  def list_exists?(name)
    list = exec_todos('SELECT name FROM lists WHERE name = $1;', name)
    !list.ntuples.zero?
  end

  def update_list_name(id, new_name)
    exec_todos('UPDATE lists SET name = $1 WHERE id = $2;', new_name, id)
  end

  def create_new_list(name)
   exec_todos('INSERT INTO lists (name) VALUES ($1);', name)
  end

  def add_todo_to_a_list(list_id, todo)
    query = 'INSERT INTO todos (name, list_id) VALUES ($1, $2);'
    exec_todos(query, todo, list_id)
  end

  def update_todo_status(list_id, id, status)
   # refactor: unused list_id
   exec_todos('UPDATE todos SET completed = $1 WHERE id = $2;', status, id)
  end

  def delete_todo_from_list(list_id, id)
   # refactor: unused list_id
   exec_todos('DELETE FROM todos WHERE id = $1', id)
  end

  def mark_all_todos_complete(list_id)
    query = 'UPDATE todos SET completed = true WHERE list_id = $1;'
    exec_todos(query, list_id)
  end

  def delete_list(id)
    exec_todos('DELETE FROM lists WHERE id = $1', id)
  end

  private

  def exec_todos(query, *args)
    logger.info("#{query}: #{args}")
    connection.exec_params(query, args)
  end
end