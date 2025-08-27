class Episode < ApplicationRecord
  belongs_to :podcast

  # Active Storage
  has_one_attached  :raw_audio
  has_one_attached  :edited_audio
  has_many_attached :assets

  # Enum to track Status state
  enum :status, { draft: 0, editing: 1, published: 2, archived: 3 }

  validates :name, :description, :release_date, presence: true
  validates :number, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
