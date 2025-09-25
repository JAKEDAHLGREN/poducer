class Episode < ApplicationRecord
  belongs_to :podcast
  # Updated enum to track the new status flow
  enum :status, {
  draft: 0,
  edit_requested: 1,
  editing: 2,
  episode_complete: 3,
  archived: 4,
  awaiting_user_review: 5,
  ready_to_publish: 6
}

  # Active Storage
  has_one_attached  :raw_audio
  has_one_attached  :edited_audio
  has_one_attached  :cover_art
  has_many_attached :assets

  validates :name, :description, :release_date, presence: true
  validates :number, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Status transition methods
  def submit_for_editing!
    return false unless draft?
    update!(status: :edit_requested)
  end

  def revert_to_draft!
    return false unless edit_requested?
    update!(status: :draft)
  end

  def start_editing!
    return false unless edit_requested?
    update!(status: :editing)
  end

  def complete_editing!
    return false unless editing?
    update!(status: :awaiting_user_review)
  end

  def re_submit_for_editing!
    return false unless awaiting_user_review?
    update!(status: :edit_requested)
  end

  def approve_episode!
    return false unless awaiting_user_review?
    update!(status: :ready_to_publish)
  end

  def publish!
    return false unless ready_to_publish?
    update!(status: :episode_complete)
  end

  def archive!
    update!(status: :archived)
  end

  # Status check methods
  def can_be_edited_by_producer?
    edit_requested? || editing?
  end

  def can_be_submitted_by_user?
    draft?
  end

  def is_editing_in_progress?
    editing?
  end

  def is_complete?
    episode_complete?
  end

  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  private

  def broadcast_status_change
    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :status),
      partial: "episodes/status_badge",
      locals: { episode: self }

    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :user_actions),
      partial: "episodes/user_actions",
      locals: { episode: self }

    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :producer_actions),
      partial: "episodes/producer_actions",
      locals: { episode: self }
  end
end
