class Podcast < ApplicationRecord
  belongs_to :user
  has_many :episodes, dependent: :destroy

  has_one_attached :cover_art
  has_many_attached :media

  # Enum to track Status state
  enum :status, { draft: 0, published: 1, archived: 2 }
  enum :episode_type, { episodic: 0, serial: 1 }

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

  # Podcast categories constant: list of selectable labels
  CATEGORIES = [
    "Arts",
    "Arts: Books",
    "Arts: Design",
    "Arts: Fashion & Beauty",
    "Arts: Food",
    "Arts: Performing Arts",
    "Arts: Visual Arts",
    "Business",
    "Business: Careers",
    "Business: Entrepreneurship",
    "Business: Investing",
    "Business: Management",
    "Business: Marketing",
    "Business: Non-Profit",
    "Comedy",
    "Comedy: Comedy Interviews",
    "Comedy: Improv",
    "Comedy: Stand-Up",
    "Education",
    "Education: Courses",
    "Education: How To",
    "Education: Language Learning",
    "Education: Self-Improvement",
    "Fiction",
    "Fiction: Comedy Fiction",
    "Fiction: Drama",
    "Fiction: Science Fiction",
    "Government",
    "Health & Fitness",
    "Health & Fitness: Alternative Health",
    "Health & Fitness: Fitness",
    "Health & Fitness: Medicine",
    "Health & Fitness: Mental Health",
    "Health & Fitness: Nutrition",
    "Health & Fitness: Sexuality",
    "History",
    "Kids & Family",
    "Kids & Family: Education for Kids",
    "Kids & Family: Parenting",
    "Kids & Family: Pets & Animals",
    "Kids & Family: Stories for Kids",
    "Leisure",
    "Leisure: Animation & Manga",
    "Leisure: Automotive",
    "Leisure: Aviation",
    "Leisure: Crafts",
    "Leisure: Games",
    "Leisure: Hobbies",
    "Leisure: Home & Garden",
    "Leisure: Video Games",
    "Music",
    "Music: Music Commentary",
    "Music: Music History",
    "Music: Music Interviews",
    "News",
    "News: Business News",
    "News: Daily News",
    "News: Entertainment News",
    "News: News Commentary",
    "News: Politics",
    "News: Sports News",
    "News: Tech News",
    "Religion & Spirituality",
    "Religion & Spirituality: Buddhism",
    "Religion & Spirituality: Christianity",
    "Religion & Spirituality: Hinduism",
    "Religion & Spirituality: Islam",
    "Religion & Spirituality: Judaism",
    "Religion & Spirituality: Religion",
    "Religion & Spirituality: Spirituality",
    "Science",
    "Science: Astronomy",
    "Science: Chemistry",
    "Science: Earth Sciences",
    "Science: Life Sciences",
    "Science: Mathematics",
    "Science: Natural Sciences",
    "Science: Nature",
    "Science: Physics",
    "Science: Social Sciences",
    "Society & Culture",
    "Society & Culture: Documentary",
    "Society & Culture: Personal Journals",
    "Society & Culture: Philosophy",
    "Society & Culture: Places & Travel",
    "Society & Culture: Relationships",
    "Sports",
    "Sports: Baseball",
    "Sports: Basketball",
    "Sports: Cricket",
    "Sports: Fantasy Sports",
    "Sports: Football",
    "Sports: Golf",
    "Sports: Hockey",
    "Sports: Rugby",
    "Sports: Running",
    "Sports: Soccer",
    "Sports: Swimming",
    "Sports: Tennis",
    "Sports: Volleyball",
    "Sports: Wilderness",
    "Sports: Wrestling",
    "TV & Film",
    "TV & Film: After Shows",
    "TV & Film: Film History",
    "TV & Film: Film Interviews",
    "TV & Film: Film Reviews",
    "TV & Film: TV Reviews",
    "Technology",
    "True Crime"
  ].freeze
end
