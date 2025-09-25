require "test_helper"

class Producer::EpisodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(role: :producer)
    sign_in_as @user

    @episode = episodes(:one)
    @episode.update!(status: :edit_requested)
  end

  test "index loads for producer" do
    get producer_episodes_url
    assert_response :success
  end

  test "start and complete editing" do
    patch start_editing_producer_episode_url(@episode)
    assert_redirected_to producer_episode_url(@episode)
    assert_equal "editing", @episode.reload.status

    patch complete_editing_producer_episode_url(@episode)
    assert_redirected_to producer_episodes_url
    assert_equal "episode_complete", @episode.reload.status
  end
end
