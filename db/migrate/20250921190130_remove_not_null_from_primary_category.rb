class RemoveNotNullFromPrimaryCategory < ActiveRecord::Migration[8.0]
  def change
    change_column_null :podcasts, :primary_category, true
  end
end
