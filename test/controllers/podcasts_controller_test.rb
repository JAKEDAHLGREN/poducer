require "test_helper"

class PodcastsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @podcast = podcasts(:one)
    @podcast.update!(user: users(:lazaro_nixon))
  end

  test "should get index" do
    get podcasts_url
    assert_response :success
  end

  test "should get new" do
    get new_podcast_url, headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    assert_response :success
  end

  test "should create draft and redirect to wizard" do
    assert_difference("Podcast.count", 1) do
      post podcasts_url, params: { podcast: { name: "My Show", description: "Great", website_url: "https://example.com" } }
    end
    assert_redirected_to podcast_wizard_url(Podcast.order(:id).last.id, :overview)
  end

  test "should show podcast" do
    get podcast_url(@podcast)
    assert_response :success
  end

  test "should get edit" do
    get edit_podcast_url(@podcast)
    assert_response :success
  end

  test "should update podcast" do
    patch podcast_url(@podcast), params: { podcast: { name: "Updated" } }
    assert_redirected_to podcast_url(@podcast)
    assert_equal "Updated", @podcast.reload.name
  end

  test "should destroy podcast" do
    assert_difference("Podcast.count", -1) do
      delete podcast_url(@podcast)
    end
    assert_redirected_to podcasts_url
  end

  test "should start wizard" do
    assert_difference("Podcast.count", 1) do
      post start_wizard_podcasts_url
    end
    created = Podcast.order(:id).last
    assert_redirected_to podcast_wizard_url(created.id, :overview)
  end
end
