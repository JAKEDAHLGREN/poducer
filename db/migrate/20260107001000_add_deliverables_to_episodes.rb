class AddDeliverablesToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :deliver_mp3, :boolean, default: false, null: false
    add_column :episodes, :deliver_mp4, :boolean, default: false, null: false
    add_column :episodes, :deliver_mov, :boolean, default: false, null: false
  end
end
