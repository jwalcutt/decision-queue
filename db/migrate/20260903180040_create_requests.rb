class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :requests do |t|
      t.string :title, null: false
      t.text :problem_statement, null: false
      t.text :expected_impact, null: false
      t.string :urgency, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_check_constraint :requests, "urgency IN ('low', 'medium', 'high')", name: "requests_urgency_check"
    add_check_constraint :requests, "status IN ('pending', 'accepted', 'deferred', 'declined')", name: "requests_status_check"
    add_index :requests, :status
  end
end
