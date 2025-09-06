class UpdateEpisodeStatusEnum < ActiveRecord::Migration[8.0]
  def up
    # Map old statuses to new statuses
    execute <<-SQL
      UPDATE episodes
      SET status = CASE
        WHEN status = 0 THEN 0  -- draft stays draft
        WHEN status = 1 THEN 2  -- editing becomes editing (new position)
        WHEN status = 2 THEN 3  -- published becomes episode_complete
        WHEN status = 3 THEN 4  -- archived becomes archived (new position)
      END
    SQL
  end

  def down
    # Revert if needed
    execute <<-SQL
      UPDATE episodes
      SET status = CASE
        WHEN status = 0 THEN 0  -- draft stays draft
        WHEN status = 1 THEN 1  -- edit_requested becomes editing (old)
        WHEN status = 2 THEN 1  -- editing becomes editing (old)
        WHEN status = 3 THEN 2  -- episode_complete becomes published
        WHEN status = 4 THEN 3  -- archived stays archived
      END
    SQL
  end
end
