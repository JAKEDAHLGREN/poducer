class Podcast < ApplicationRecord
  belongs_to :user
  has_many :episodes, dependent: :destroy

  has_one_attached :cover_art
  has_many_attached :media

  # Enum to track Status state
  enum :status, { draft: 0, published: 1, archived: 2 }

  # Validations - simplified
  validates :name, :description, presence: true
  validates :website_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :primary_category, presence: true, on: :categories_step

  # Normalize categories only
  before_validation do
    self.primary_category   = primary_category&.strip
    self.secondary_category = secondary_category&.strip.presence
    self.tertiary_category  = tertiary_category&.strip.presence
  end
end
