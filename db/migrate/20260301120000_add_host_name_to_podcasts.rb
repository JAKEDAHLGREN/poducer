class AddHostNameToPodcasts < ActiveRecord::Migration[8.0]
  def change
    add_column :podcasts, :host_name, :string
  end
end
