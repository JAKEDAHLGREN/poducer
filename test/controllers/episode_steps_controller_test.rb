require "test_helper"

class EpisodeStepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    sign_in_as(@user)
    @podcast = podcasts(:one)
    @podcast.update!(user: @user)
    @episode = episodes(:one)
    @episode.update!(podcast: @podcast, status: :draft, name: "Test Episode", description: "A description", notes: "Some notes")
  end

  # === Step Rendering ===

  test "show overview step" do
    get podcast_episode_wizard_url(@podcast, @episode, :overview)
    assert_response :success
  end

  test "show assets step" do
    get podcast_episode_wizard_url(@podcast, @episode, :assets)
    assert_response :success
  end

  test "show details step" do
    get podcast_episode_wizard_url(@podcast, @episode, :details)
    assert_response :success
  end

  test "show summary step" do
    get podcast_episode_wizard_url(@podcast, @episode, :summary)
    assert_response :success
  end

  # === Validation Per Step ===

  test "update overview with blank name re-renders" do
    patch podcast_episode_wizard_url(@podcast, @episode, :overview), params: { episode: { name: "", description: "" } }
    assert_response :success
  end

  test "update details with blank notes re-renders" do
    patch podcast_episode_wizard_url(@podcast, @episode, :details), params: { episode: { notes: "" } }
    assert_response :success
  end

  # === Step Advancement ===

  test "valid overview patch redirects to next step" do
    patch podcast_episode_wizard_url(@podcast, @episode, :overview), params: { episode: { name: "Ep Name", description: "Desc" } }
    assert_redirected_to podcast_episode_wizard_url(@podcast, @episode, :assets)
  end

  test "valid details patch redirects to summary" do
    patch podcast_episode_wizard_url(@podcast, @episode, :details), params: { episode: { notes: "Production notes here" } }
    assert_redirected_to podcast_episode_wizard_url(@podcast, @episode, :summary)
  end

  test "summary patch finishes wizard and redirects to episode show" do
    patch podcast_episode_wizard_url(@podcast, @episode, :summary), params: { episode: { name: "Ep Name", description: "Desc", notes: "Notes" } }
    assert_redirected_to podcast_episode_url(@podcast, @episode)
  end

  # === Raw Audio Upload ===

  test "raw audio upload attaches file" do
    file = fixture_file_upload("test_audio.wav", "audio/mpeg")
    patch upload_raw_audio_podcast_episode_wizard_index_url(@podcast, @episode),
          params: { file: file }
    assert_response :success
    assert @episode.reload.raw_audio.attached?
  end

  # === Preserve Number ===

  test "existing episode number preserved when blank number param sent" do
    original_number = @episode.number
    patch podcast_episode_wizard_url(@podcast, @episode, :summary),
          params: { episode: { name: "Ep", description: "Desc", notes: "Notes", number: "" } }
    assert_redirected_to podcast_episode_url(@podcast, @episode)
    assert_equal original_number, @episode.reload.number
  end

  # === Authorization ===

  test "non-owner is redirected from wizard" do
    other_user = users(:two)
    sign_in_as(other_user)
    get podcast_episode_wizard_url(@podcast, @episode, :overview)
    assert_redirected_to podcast_episodes_url(@podcast)
  end
end
