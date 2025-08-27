class CreateEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :episodes do |t|
      t.references :podcast, null: false, foreign_key: true

      t.string :name, null: false
      t.integer :number, null: false
      t.text :links
      t.date :release_date
      t.text :description
      t.text :notes
      t.string :format

      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :episodes, [ :podcast_id, :number ], unique: true
    add_index :episodes, :status
    add_index :episodes, :release_date
  end
end
