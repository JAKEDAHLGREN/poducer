class Podcast < ApplicationRecord
  belongs_to :user
  has_one_attached :cover_art
  has_many_attached :media
  has_many :episodes

  # Enum to track Status state
  enum :status, { draft: 0, published: 1, archived: 2 }

  # Validations
  validates :name, :description, :primary_category, presence: true
  validates :website_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true

  # (Optional) normalize/canonicalize categories and URLs
  before_validation do
    self.website_url = website_url&.strip
    self.primary_category   = primary_category&.strip
    self.secondary_category = secondary_category&.strip.presence
    self.tertiary_category  = tertiary_category&.strip.presence
  end
end
