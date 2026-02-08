require "test_helper"

class PodcastTest < ActiveSupport::TestCase
  setup do
    @podcast = podcasts(:one)
  end

  # === Validations ===

  test "requires name" do
    @podcast.name = nil
    assert_not @podcast.valid?
    assert_includes @podcast.errors[:name], "can't be blank"
  end

  test "requires description" do
    @podcast.description = nil
    assert_not @podcast.valid?
    assert_includes @podcast.errors[:description], "can't be blank"
  end

  test "website_url allows blank" do
    @podcast.website_url = ""
    assert @podcast.valid?
  end

  test "website_url rejects invalid URLs" do
    @podcast.website_url = "not-a-url"
    assert_not @podcast.valid?
    assert_includes @podcast.errors[:website_url], "must be a valid URL"
  end

  test "primary_category required on categories_step" do
    @podcast.primary_category = nil
    assert_not @podcast.valid?(:categories_step)
    assert_includes @podcast.errors[:primary_category], "can't be blank"
  end

  # === Enums ===

  test "status enum values" do
    assert_equal({ "draft" => 0, "published" => 1, "archived" => 2 }, Podcast.statuses)
  end

  test "episode_type enum values" do
    assert_equal({ "episodic" => 0, "serial" => 1 }, Podcast.episode_types)
  end

  # === Category Normalization ===

  test "strips whitespace from categories" do
    @podcast.primary_category = "  Arts  "
    @podcast.secondary_category = "  Comedy  "
    @podcast.valid?
    assert_equal "Arts", @podcast.primary_category
    assert_equal "Comedy", @podcast.secondary_category
  end

  test "blank secondary and tertiary become nil" do
    @podcast.secondary_category = "  "
    @podcast.tertiary_category = "  "
    @podcast.valid?
    assert_nil @podcast.secondary_category
    assert_nil @podcast.tertiary_category
  end

  # === Associations + Constants ===

  test "belongs to user" do
    assert_respond_to @podcast, :user
    assert_instance_of User, @podcast.user
  end

  test "has many episodes with dependent destroy" do
    assert_respond_to @podcast, :episodes
    reflection = Podcast.reflect_on_association(:episodes)
    assert_equal :destroy, reflection.options[:dependent]
  end

  test "CATEGORIES is frozen and non-empty" do
    assert Podcast::CATEGORIES.frozen?
    assert Podcast::CATEGORIES.size > 0
  end
end
