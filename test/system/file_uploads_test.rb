require "application_system_test_case"

class FileUploadsTest < ApplicationSystemTestCase
  # Disable parallel execution for system tests to avoid database isolation issues
  parallelize(workers: 1)

  setup do
    # Use unique emails per test run to avoid conflicts
    @test_id = SecureRandom.hex(4)

    @user = User.create!(
      email: "uploader_#{@test_id}@example.com",
      password: "password123",
      password_confirmation: "password123",
      verified: true
    )

    @producer = User.create!(
      email: "producer_#{@test_id}@example.com",
      password: "password123",
      password_confirmation: "password123",
      verified: true,
      role: :producer
    )

    # Create test files
    @test_image_path = Rails.root.join("test/fixtures/files/test_cover.png")
    @test_audio_path = Rails.root.join("test/fixtures/files/test_audio.wav")

    # Create fixtures directory and test files if they don't exist
    FileUtils.mkdir_p(Rails.root.join("test/fixtures/files"))

    unless File.exist?(@test_image_path)
      # Create a minimal valid PNG (1x1 orange pixel)
      png_data = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==")
      File.write(@test_image_path, png_data, mode: "wb")
    end

    unless File.exist?(@test_audio_path)
      # Create a minimal valid WAV file header
      wav_data = "RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00D\xAC\x00\x00\x88X\x01\x00\x02\x00\x10\x00data\x00\x00\x00\x00"
      File.write(@test_audio_path, wav_data, mode: "wb")
    end
  end

  teardown do
    # Clean up test users and their data
    User.where("email LIKE ?", "%_#{@test_id}@example.com").destroy_all if @test_id
  end

  # ==================
  # Helper Methods
  # ==================

  def sign_in_as_user
    visit sign_in_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Continue"
    assert_current_path podcasts_path
  end

  def sign_in_as_producer
    visit sign_in_path
    fill_in "Email", with: @producer.email
    fill_in "Password", with: "password123"
    click_button "Continue"
    # Producers redirect to producer dashboard
    assert_current_path producer_episodes_path
  end

  def create_podcast_for_user
    @podcast = Podcast.create!(
      user: @user,
      name: "Test Podcast",
      description: "A test podcast for file uploads",
      status: :published,
      primary_category: "Technology"
    )
  end

  def create_episode_for_podcast
    @episode = Episode.create!(
      podcast: @podcast,
      name: "Test Episode",
      description: "A test episode",
      number: 1,
      status: :draft,
      notes: "Test notes"
    )
  end

  # ==================
  # Podcast Wizard Tests
  # ==================

  test "podcast wizard shows file upload components on media step" do
    sign_in_as_user

    click_link "Create New Podcast"

    # Should be on overview step - heading is h2
    assert_selector "h2", text: "PODCAST DETAILS"

    # Fill in overview
    fill_in "Name", with: "Upload Test Podcast"
    fill_in "Description", with: "Testing file uploads"
    click_button "Next"

    # Should be on media step - verify file upload component is present
    assert_selector "[data-controller='file-upload']"
    assert_selector "[data-file-upload-target='dropZone']"
    assert_selector "button", text: "Browse Files"
  end

  test "podcast wizard displays instructions in dropzone" do
    sign_in_as_user
    click_link "Create New Podcast"

    fill_in "Name", with: "Upload Test Podcast"
    fill_in "Description", with: "Testing file uploads"
    click_button "Next"

    # Verify dropzone has instructions
    assert_selector "[data-file-upload-target='instructions']"
  end

  # ==================
  # Episode Form Tests
  # ==================

  test "episode edit form shows all upload sections" do
    sign_in_as_user
    create_podcast_for_user
    create_episode_for_podcast

    visit edit_podcast_episode_path(@podcast, @episode)

    # Verify all upload sections are present
    assert_text "Cover Art"
    assert_text "Raw Audio"
    assert_text "Additional Assets"

    # Verify file upload components
    assert_selector "[data-controller='file-upload']", minimum: 3
  end

  test "episode edit form shows existing assets" do
    sign_in_as_user
    create_podcast_for_user
    create_episode_for_podcast

    # Attach an asset
    @episode.assets.attach(
      io: File.open(@test_audio_path),
      filename: "existing_audio.wav",
      content_type: "audio/wav"
    )

    visit edit_podcast_episode_path(@podcast, @episode)

    # Verify existing asset is shown
    assert_text "existing_audio.wav"
  end

  # ==================
  # File Upload Component Tests
  # ==================

  test "file upload component has correct data attributes" do
    sign_in_as_user
    create_podcast_for_user
    create_episode_for_podcast

    visit edit_podcast_episode_path(@podcast, @episode)

    # Cover art component should be single file, images only
    cover_component = find("[data-file-upload-attachment-name-value='cover_art']")
    assert_equal "false", cover_component["data-file-upload-multiple-value"]
    assert cover_component["data-file-upload-accept-value"].include?("image/")

    # Assets component should allow multiple files
    assets_component = find("[data-file-upload-attachment-name-value='assets']")
    assert_equal "true", assets_component["data-file-upload-multiple-value"]
  end

  test "file upload dropzone has proper styling elements" do
    sign_in_as_user
    create_podcast_for_user
    create_episode_for_podcast

    visit edit_podcast_episode_path(@podcast, @episode)

    # Verify dropzone elements
    assert_selector "[data-file-upload-target='dropZone']", minimum: 3
    assert_selector "[data-file-upload-target='input']", visible: :hidden, minimum: 3
    assert_selector "[data-file-upload-target='fileList']", minimum: 3
  end

  # ==================
  # Producer Tests
  # ==================

  test "producer can see deliverables upload on episode page" do
    create_podcast_for_user
    create_episode_for_podcast
    @episode.update!(status: :edit_requested)

    sign_in_as_producer

    visit producer_episode_path(@episode)

    # Verify deliverables upload component is present
    assert_selector "[data-file-upload-attachment-name-value='deliverables']"
  end

  # ==================
  # Cover Art Fallback Test
  # ==================

  test "episode form shows podcast cover fallback hint" do
    sign_in_as_user
    create_podcast_for_user

    # Attach cover art to podcast
    @podcast.cover_art.attach(
      io: File.open(@test_image_path),
      filename: "podcast_cover.png",
      content_type: "image/png"
    )

    create_episode_for_podcast

    visit edit_podcast_episode_path(@podcast, @episode)

    # Should show fallback hint since episode has no cover but podcast does
    assert_text "podcast cover will be used as fallback"
  end
end
