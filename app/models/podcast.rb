class Podcast < ApplicationRecord
  belongs_to :user
  has_many :episodes, dependent: :destroy

  has_one_attached :cover_art
  has_many_attached :media

  # Enum to track Status state
  enum :status, { draft: 0, published: 1, archived: 2 }
  enum :episode_type, { episodic: 0, serial: 1 }

  # Validations - simplified
  validates :name, :description, :host_name, presence: true
  validates :description, length: { maximum: 4_000, message: "must be under 4,000 characters" }
  validates :website_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :primary_category, presence: true, on: :categories_step
  validate :cover_art_attached, on: [ :media_step, :summary_step ]

  def cover_art_attached
    return if cover_art.attached?
    errors.add(:cover_art, "must be present")
  end

  # Normalize categories only
  before_validation do
    self.primary_category   = primary_category&.strip
    self.secondary_category = secondary_category&.strip.presence
    self.tertiary_category  = tertiary_category&.strip.presence
  end

  # Podcast categories constant: list of selectable labels(Generic options only for now)
  CATEGORIES = [
    "Arts",
    "Business",
    "Comedy",
    "Education",
    "Fiction",
    "Government",
    "Health & Fitness",
    "History",
    "Kids & Family",
    "Leisure",
    "Music",
    "News",
    "Religion & Spirituality",
    "Science",
    "Society & Culture",
    "Sports",
    "TV & Film",
    "Technology",
    "True Crime"
  ].freeze
end
