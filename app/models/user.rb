class User < ApplicationRecord
  has_secure_password

  has_many :podcasts, dependent: :destroy
  has_many :sessions, dependent: :destroy

  # Rails 7.1+/8 nicety:
  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  attribute :role, :integer, default: 0
  enum :role, { user: 0, producer: 1, admin: 2 }
  # TODO: Implementation plan options later
  # enum plan: { base: 0, pro: 1, enterprise: 2 }

  validates :email, presence: true, uniqueness: true

  # Token generation for email verification and password reset
  def generate_token_for(purpose)
    signed_id(purpose: purpose, expires_in: 20.minutes)
  end

  def self.find_by_token_for!(purpose, token)
    find_signed!(token, purpose: purpose)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise StandardError, "Invalid token"
  end
end
