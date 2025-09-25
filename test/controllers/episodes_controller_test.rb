require "test_helper"

class EpisodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @podcast = podcasts(:one)
    @podcast.update!(user: users(:lazaro_nixon))
    @episode = episodes(:one)
    @episode.update!(podcast: @podcast, status: :draft)
  end

  test "index lists episodes" do
    get podcast_episodes_url(@podcast)
    assert_response :success
  end

  test "new renders" do
    get new_podcast_episode_url(@podcast)
    assert_response :success
  end

  test "create episode" do
    assert_difference("Episode.count", 1) do
      post podcast_episodes_url(@podcast), params: { episode: { name: "Ep 1", number: 10, description: "desc", release_date: Date.today } }
    end
    created = Episode.order(:id).last
    assert_redirected_to podcast_episode_url(@podcast, created)
  end

  test "show episode" do
    get podcast_episode_url(@podcast, @episode)
    assert_response :success
  end

  test "edit only when draft" do
    get edit_podcast_episode_url(@podcast, @episode)
    assert_response :success

    @episode.update!(status: :edit_requested)
    get edit_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
  end

  test "update episode" do
    patch podcast_episode_url(@podcast, @episode), params: { episode: { name: "Updated" } }
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "Updated", @episode.reload.name
  end

  test "destroy episode" do
    assert_difference("Episode.count", -1) do
      delete podcast_episode_url(@podcast, @episode)
    end
    assert_redirected_to podcast_episodes_url(@podcast)
  end

   test "submit, start editing, complete editing, approve, publish, revert" do
    patch submit_episode_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "edit_requested", @episode.reload.status

    patch start_editing_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "editing", @episode.reload.status

    patch complete_editing_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "awaiting_user_review", @episode.reload.status

    patch approve_episode_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "ready_to_publish", @episode.reload.status

    patch publish_episode_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "episode_complete", @episode.reload.status

    # revert only allowed from edit_requested; set and then revert
    @episode.update!(status: :edit_requested)
    patch revert_to_draft_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "draft", @episode.reload.status
  end

  test "re_submit sends episode back to edit_requested" do
    # Move to awaiting_user_review
    patch submit_episode_podcast_episode_url(@podcast, @episode)
    patch start_editing_podcast_episode_url(@podcast, @episode)
    patch complete_editing_podcast_episode_url(@podcast, @episode)
    assert_equal "awaiting_user_review", @episode.reload.status

    # Re-submit for more edits
    patch re_submit_for_editing_podcast_episode_url(@podcast, @episode)
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal "edit_requested", @episode.reload.status
  end
end
