class AddEpisodeCreationFieldsToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :media_type, :string
    add_column :episodes, :episode_kind, :string
    add_column :episodes, :edits_timestamps, :text
    add_column :episodes, :explicit, :boolean, default: false, null: false
  end
end
