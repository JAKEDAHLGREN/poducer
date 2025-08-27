# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  # Rails 7.1+/8 nicety:
  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  attribute :role, :integer, default: 0
  enum :role, { user: 0, producer: 1, admin: 2 }
  # TODO: Implementation plan options later
  # enum plan: { base: 0, pro: 1, enterprise: 2 }
  validates :email, presence: true, uniqueness: true
  has_many :podcasts, dependent: :destroy
  has_many :sessions, dependent: :destroy
end
