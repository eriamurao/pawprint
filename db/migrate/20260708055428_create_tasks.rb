class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.text :content, null: false
      t.integer :log_year, null: false
      t.integer :log_month, null: false
      t.integer :log_day, null: true
      t.integer :status, null: false, default: 0
      t.boolean :priority, null: false, default: false
      t.bigint :created_from_id, null: true
      t.timestamps
    end

    add_index :tasks, :created_from_id
  end
end
