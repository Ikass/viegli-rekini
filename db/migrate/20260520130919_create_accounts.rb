class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      # null: false enforces this at the database level — even if Rails
      # validations are bypassed (e.g. update_column), the DB will reject
      # a record without a name. Always add this for required columns.
      t.string :name, null: false

      t.timestamps
    end
  end
end
