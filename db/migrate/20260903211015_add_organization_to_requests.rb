class AddOrganizationToRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :requests, :organization, :string

    # Existing rows name the partner at the end of the title ("... for Acme").
    execute <<~SQL
      UPDATE requests
      SET organization = COALESCE(substring(title FROM ' for (.+)$'), 'Unknown partner')
      WHERE organization IS NULL
    SQL

    change_column_null :requests, :organization, false
  end

  def down
    remove_column :requests, :organization
  end
end
