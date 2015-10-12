require "too_done/version"
require "too_done/init_db"
require "too_done/user"
require "too_done/session"
require "too_done/list"
require "too_done/task"

require "thor"
require "pry"

module TooDone
  class App < Thor

    desc "add 'TASK'", "Add a TASK to a todo list."
    option :list, :aliases => :l, :default => "Chores",
      :desc => "The todo list which the task will be filed under."
    option :date, :aliases => :d,
      :desc => "A Due Date in YYYY-MM-DD format."
    def add(task)
      list = current_user.lists.find_or_create_by(title: options[:list])
      if options[:date] != nil
        new_task = list.tasks.create(description: task,
                                     due_date: Date.parse(options[:date]))
      else 
        new_task = list.tasks.create(description: task) 
      end
    end

    desc "edit", "Edit a task from a todo list."
    option :list, :aliases => :l, :default => "Chores",
      :desc => "The todo list whose tasks will be edited."
    def edit
      current_list = current_user.lists.find_by(title: options[:list])
      tasks = current_list.tasks
      if current_list && tasks.exists?
        puts "Current List: #{current_list.title}"
        display_tasks(tasks)
        puts "Which task would you like to edit?"
        input = STDIN.gets.chomp
        old_task = tasks.find_by(description: input)
        puts "Please update your task now: "
        input = STDIN.gets.chomp
        puts "Please add a due date (YYYY-MM-DD): "
        date_input = STDIN.gets.chomp
        old_task.update(description: input, 
                        due_date: Date.parse(date_input))
      else
        exit
      end
    end

    desc "done", "Mark a task as completed."
    option :list, :aliases => :l, :default => "Chores",
      :desc => "The todo list whose tasks will be completed."

    def done
      current_list = current_user.lists.find_by(title: options[:list])
      tasks = current_list.tasks

      if current_list && tasks.exists?
        puts "Current List: #{current_list.title}"
        puts "Current Tasks: " 
        display_tasks(tasks)
        puts "\nWhich task would you like to mark as complete?"
        input = STDIN.gets.chomp
        finished_word = tasks.find_by(description: input)
        finished_word.update_name
        finished_word.done
        current_list = current_user.lists.find_by(title: options[:list])
        tasks = current_list.tasks
        display_tasks(tasks)
        puts "\nWould you like to mark another task complete? (Y/N)"
        input = STDIN.gets.chomp.upcase
        until input == "N"
          puts "Current Tasks: "
          display_tasks(tasks)
          puts "\nWhich task would you like to mark as complete?"
          input = STDIN.gets.chomp
          finished_task = tasks.find_by(description: input)
          finished_task.update_name
          finished_task.done
          current_list = current_user.lists.find_by(title: options[:list])
          tasks = current_list.tasks
          if tasks.any? do |task|
            task.state == false
            puts "Would you like to mark another task as complete? (Y/N)"
            input == STDIN.gets.chomp.upcase
            end
          else
            exit
          end
        end
        exit
      else
        exit
      end
    end

    desc "show", "Show the tasks on a todo list in reverse order."
    option :list, :aliases => :l, :default => "Chores",
      :desc => "The todo list whose tasks will be shown."
    option :completed, :aliases => :c, :default => false, :type => :boolean,
      :desc => "Whether or not to show already completed tasks."
    option :sort, :aliases => :s, :enum => ["history", "overdue"],
      :desc => "Sorting by 'history' (chronological) or 'overdue'.
      \t\t\t\t\tLimits results to those with a due date."
    def show

      list = current_user.lists.find_or_create_by(title: options[:list])
      tasks = list.tasks
      
      puts "Current List: #{list.title}"
      puts "Current Tasks: "
      if options[:completed] != nil && options[:sort] == "history"
        display_tasks(tasks)
      elsif options[:sort] == "history"
        tasks.each do |task|
          puts task.description if task.state == false
          end
      elsif options[:completed] != nil && options[:sort] == "overdue"       
        tasks.each do |task|
          if task.due_date 
            puts "#{task.description} - due date: #{task.due_date}" if (Date.today > task.due_date)
            end
          end
      elsif options[:sort] == "overdue"
        tasks.each do |task|
          if task.state == false && task.due_date 
            puts "#{task.description} - due date: #{task.due_date}" if (Date.today > task.due_date)
            end
          end
      else
        tasks.order(id: :desc).each { |task| puts task.description }
      end
    end

    desc "delete [LIST OR USER]", "Delete a todo list or a user."
    option :list, :aliases => :l,
      :desc => "The todo list which will be deleted (including items)."
    option :user, :aliases => :u,
      :desc => "The user which will be deleted (including lists and items)."
    
    def delete
      if options[:list] && options[:user]
        puts "Please enter a single list or single user."
        exit
      elsif options[:list] == nil && options[:user] == nil
        puts "Please enter either a single list or single user."
        exit
      end
      if options[:list]
        current_list = current_user.lists.find_by(title: options[:list])
        if current_list == nil
          puts "List could not be found."
          exit
        else
          puts "Are you sure you'd like to permanently delete list #{current_list.title}? (Y/N)"
          puts "Note that all associated tasks will be destroyed."
          input = STDIN.gets.chomp.upcase
          unless input == "N"
            current_list.destroy
          end
        end
      else
        user = User.find_by(name: options[:user])
        if user == nil
          puts "User could not be found."
          exit
        else
          puts "Are you sure you'd like to permanently delete user #{user.name}? (Y/N)"
          puts "Note that all associated to-do lists and tasks will be destroyed."
          input = STDIN.gets.chomp
          unless input == "N"
            user.destroy
          end
        end
        end
    end

    desc "switch USER", "Switch session to manage USER's todo lists."
    def switch(username)
      user = User.find_or_create_by(name: username)
      user.sessions.create
    end

    private

    def display_tasks(tasks)
      tasks.each { |task| puts task.description }
    end

    def current_user
      Session.last.user
    end
  end
end

TooDone::App.start(ARGV)
