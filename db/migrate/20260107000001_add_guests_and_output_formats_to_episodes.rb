class AddGuestsAndOutputFormatsToEpisodes < ActiveRecord::Migration[8.0]
  def change
    add_column :episodes, :guests, :text
    add_column :episodes, :output_formats, :text
  end
end
