require "test_helper"

class PodcastStepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @podcast = podcasts(:one)
    @podcast.update!(user: users(:lazaro_nixon), website_url: "https://example.com")
  end

  test "wizard show renders" do
    get podcast_wizard_url(@podcast.id, :overview)
    assert_response :success
  end

  test "overview validation failure stores errors and renders" do
    patch podcast_wizard_url(@podcast.id, :overview), params: { podcast: { name: "", description: "" } }
    assert_response :success
    assert_includes session[:validation_errors] || [], "Name can't be blank"
  end

  test "overview success advances to next step" do
    patch podcast_wizard_url(@podcast.id, :overview), params: { podcast: { name: "My Show", description: "Great" } }
    assert_redirected_to podcast_wizard_url(@podcast.id, :cover)
  end

  test "finish publishes and redirects to index" do
    @podcast.update!(name: "My Show", description: "Great")
    patch podcast_wizard_url(@podcast.id, :summary)
    assert_redirected_to podcasts_url
    assert_equal "published", @podcast.reload.status
  end
end
