class CreateAppSecrets < ActiveRecord::Migration
  def self.up
    create_table :app_secrets do |t|
      t.string :name
      t.string :value

      t.timestamps
    end
  end

  def self.down
    drop_table :app_secrets
  end
end
