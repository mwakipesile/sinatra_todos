require 'pg'

class DatabasePersistence
  attr_accessor :connection, :logger

  def initialize(logger)
    @connection = PG.connect(dbname: 'todos', password: 'Collapse2')
    @logger = logger
  end

  def fetch_list(list_id)
    query = <<-Q
      SELECT l.name,
       COUNT(t.id) AS todos_count,
       COUNT(NULLIF(t.completed, true)) AS remaining_todos_count
      FROM lists AS l LEFT JOIN todos AS t ON l.id = t.list_id
      WHERE l.id = $1
      GROUP BY l.id;
      Q

    tuples = exec_todos(query, list_id)
    tuples.map do |tuple|
      { 
        name: tuple['name'],
        todos_count: tuple['todos_count'].to_i,
        remaining_todos_count: tuple['remaining_todos_count'].to_i
      }
    end.first
  end

  def fetch_todos(list_id)
    query = 'SELECT id, name, completed FROM todos WHERE list_id = $1'
    tuples = exec_todos(query, list_id)

    tuples.map do |todo|
      status = todo['completed'] == 't'
      { id: todo['id'].to_i, name: todo['name'], completed: status }
    end
  end
    
  def list_name(id)
    list = exec_todos('SELECT name FROM lists WHERE id = $1', id)
    return if list.ntuples.zero?

    list.first['name']
  end

  def all_lists
    query = <<-Q
      SELECT l.id, l.name,
       COUNT(t.id) AS todos_count,
       COUNT(NULLIF(t.completed, true)) AS remaining_todos_count
      FROM lists AS l LEFT JOIN todos AS t ON l.id = t.list_id
      GROUP BY l.id;
      Q
   
    tuples = exec_todos(query)
    tuples.map do |tuple|
      { 
        id: tuple['id'].to_i,
        name: tuple['name'],
        todos_count: tuple['todos_count'].to_i,
        remaining_todos_count: tuple['remaining_todos_count'].to_i
      }
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
   query = 'UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3;'
   exec_todos(query, status, id, list_id)
  end

  def delete_todo_from_list(list_id, id)
   exec_todos('DELETE FROM todos WHERE id = $1 AND list_id = $2', id, list_id)
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