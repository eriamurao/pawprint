class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.text :description, null: true
      t.integer :log_year, null: false
      t.integer :log_month, null: false
      t.integer :log_day, null: true
      t.integer :status, null: false, default: 0
      t.boolean :priority, null: false, default: false
      t.references :created_from, null: true, foreign_key: { to_table: :tasks }
      t.timestamps
    end
  end
end
