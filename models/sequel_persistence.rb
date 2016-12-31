require 'sequel'

class SequelPersistence
  DB = Sequel.connect('postgres://Edgar:Collapse2@localhost/todos')

  attr_accessor :lists, :todos, :logger

  def initialize(logger)
    DB.logger = logger
    @lists = DB[:lists]
    @todos = DB[:todos]
  end

  def fetch_list(list_id)
    DB[:lists___l].select do 
      [ l__name, count(:t__id).as(todos_count),
        count(nullif(:t__completed, true)).as(remaining_todos_count) ]
    end
    .left_join(:todos___t, l__id: :t__list_id)
    .where(l__id: list_id)
    .group(:l__id).first
  end

  def fetch_todos(list_id)
    todos.where(list_id: list_id)
  end
    
  def list_name(id)
    lists.select(:name).where(id: id).first[:name]
  end

  def all_lists   
    DB[:lists___l].select_all(:l).select_append do 
      [ count(:t__id).as(todos_count),
        count(nullif(:t__completed, true)).as(remaining_todos_count) ]
    end
    .left_join(:todos___t, l__id: :t__list_id)
    .group(:l__id).order(:l__id)
  end 

  def list_exists?(name)
    lists.where(name: name).count > 0
  end

  def update_list_name(id, new_name)
    lists.where(id: id).update(name: new_name)
  end

  def create_new_list(name)
    lists.insert(name: name)
  end

  def add_todo_to_a_list(list_id, todo)
    todos.insert(name: todo, list_id: list_id)
  end

  def update_todo_status(list_id, id, status)
    todos.where(id: id, list_id: list_id).update(completed: status)
  end

  def delete_todo_from_list(list_id, id)
    todos.where(id: id, list_id: list_id).delete
  end

  def mark_all_todos_complete(list_id)
    todos.where(list_id: list_id).update(completed: true)
  end

  def delete_list(id)
    lists.where(id: id).delete
  end
end