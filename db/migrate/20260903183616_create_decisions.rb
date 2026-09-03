class CreateDecisions < ActiveRecord::Migration[8.1]
  def change
    create_table :decisions do |t|
      t.references :request, null: false, foreign_key: true
      t.string :decision_type, null: false
      t.text :reason, null: false

      t.timestamps
    end

    add_check_constraint :decisions, "decision_type IN ('accepted', 'deferred', 'declined')", name: "decisions_decision_type_check"
  end
end
