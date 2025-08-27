class CreatePodcasts < ActiveRecord::Migration[8.0]
  def change
    create_table :podcasts do |t|
      t.references :user, null: false, foreign_key: true

      t.string :name, null: false
      t.text :description
      t.string :website_url

      t.string :primary_category, null: false
      t.string :secondary_category   # optional by default
      t.string :tertiary_category    # optional by default

      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :podcasts, :status
    add_index :podcasts, :primary_category
  end
end
