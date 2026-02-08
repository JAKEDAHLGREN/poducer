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

  # === Authorization ===

  test "regular user rejected from producer namespace" do
    regular_user = users(:two)
    regular_user.update!(role: :user)
    sign_in_as(regular_user)
    get producer_episodes_url
    assert_redirected_to root_url
  end

  # === Guards ===

  test "complete_editing blocked without deliverables or edited_audio" do
    @episode.update!(status: :editing)
    patch complete_editing_producer_episode_url(@episode)
    assert_redirected_to producer_episode_url(@episode)
    assert_equal "editing", @episode.reload.status
  end

  # === Show ===

  test "producer show renders successfully" do
    get producer_episode_url(@episode)
    assert_response :success
  end

  # === Update ===

  test "producer can update episode notes" do
    patch producer_episode_url(@episode), params: { episode: { notes: "Updated producer notes" } }
    assert_redirected_to producer_episode_url(@episode)
    assert_equal "Updated producer notes", @episode.reload.notes
  end

  # === Upload ===

  test "upload_assets attaches deliverables" do
    @episode.update!(status: :editing)
    file = fixture_file_upload("test_audio.wav", "audio/mpeg")
    patch upload_assets_producer_episode_url(@episode), params: { files: [ file ] }
    assert @episode.reload.deliverables.attached?
  end

  test "start and complete editing" do
    patch start_editing_producer_episode_url(@episode)
    assert_redirected_to producer_episode_url(@episode)
    assert_equal "editing", @episode.reload.status

    @episode.deliverables.attach(io: StringIO.new("fake deliverable"), filename: "final.mp3", content_type: "audio/mpeg")

    patch complete_editing_producer_episode_url(@episode)
    assert_redirected_to producer_episodes_url
    assert_equal "awaiting_user_review", @episode.reload.status
  end
end
