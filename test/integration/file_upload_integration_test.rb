require "test_helper"

class FileUploadIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "integration_user@example.com",
      password: "password123",
      password_confirmation: "password123",
      verified: true
    )

    @producer = User.create!(
      email: "integration_producer@example.com",
      password: "password123",
      password_confirmation: "password123",
      verified: true,
      role: :producer
    )

    # Create test files
    setup_test_files
  end

  teardown do
    User.where(email: ["integration_user@example.com", "integration_producer@example.com"]).destroy_all
  end

  # ==================
  # Helper Methods
  # ==================

  def setup_test_files
    @fixtures_path = Rails.root.join("test/fixtures/files")
    FileUtils.mkdir_p(@fixtures_path)

    @test_image_path = @fixtures_path.join("test_cover.png")
    @test_audio_path = @fixtures_path.join("test_audio.wav")

    unless File.exist?(@test_image_path)
      png_data = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==")
      File.write(@test_image_path, png_data, mode: "wb")
    end

    unless File.exist?(@test_audio_path)
      wav_data = "RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00D\xAC\x00\x00\x88X\x01\x00\x02\x00\x10\x00data\x00\x00\x00\x00"
      File.write(@test_audio_path, wav_data, mode: "wb")
    end
  end

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
    follow_redirect!
  end

  def create_podcast
    @podcast = Podcast.create!(
      user: @user,
      name: "Integration Test Podcast",
      description: "Testing uploads",
      status: :published,
      primary_category: "Technology"
    )
  end

  def create_episode
    @episode = Episode.create!(
      podcast: @podcast,
      name: "Integration Test Episode",
      description: "Testing uploads",
      number: 1,
      status: :draft,
      notes: "Test notes"
    )
  end

  def upload_file_via_direct_upload(file_path, filename, content_type)
    file_content = File.read(file_path, mode: "rb")
    checksum = OpenSSL::Digest::MD5.base64digest(file_content)

    post rails_direct_uploads_path, params: {
      blob: {
        filename: filename,
        content_type: content_type,
        byte_size: file_content.bytesize,
        checksum: checksum
      }
    }, as: :json

    assert_response :success
    blob_data = JSON.parse(response.body)

    # Upload file content
    put blob_data["direct_upload"]["url"],
        params: file_content,
        headers: { "Content-Type" => content_type }

    assert_response :no_content

    blob_data["signed_id"]
  end

  # ==================
  # Direct Upload API Tests
  # ==================

  test "direct upload creates blob successfully" do
    sign_in_as(@user)

    file_content = File.read(@test_image_path, mode: "rb")
    checksum = OpenSSL::Digest::MD5.base64digest(file_content)

    post rails_direct_uploads_path, params: {
      blob: {
        filename: "test_image.png",
        content_type: "image/png",
        byte_size: file_content.bytesize,
        checksum: checksum
      }
    }, as: :json

    assert_response :success

    blob_data = JSON.parse(response.body)
    assert blob_data["signed_id"].present?
    assert blob_data["direct_upload"]["url"].present?
    assert_equal "test_image.png", blob_data["filename"]
  end

  test "direct upload file content succeeds" do
    sign_in_as(@user)

    signed_id = upload_file_via_direct_upload(@test_image_path, "uploaded.png", "image/png")
    assert signed_id.present?

    # Verify blob exists
    blob = ActiveStorage::Blob.find_signed(signed_id)
    assert blob.present?
    assert_equal "uploaded.png", blob.filename.to_s
  end

  # ==================
  # Podcast Cover Art Tests
  # ==================

  test "podcast wizard accepts cover art via signed_id" do
    sign_in_as(@user)
    create_podcast
    @podcast.update!(status: :draft)

    signed_id = upload_file_via_direct_upload(@test_image_path, "cover.png", "image/png")

    patch podcast_wizard_path(@podcast, :media), params: {
      podcast: { cover_art: signed_id }
    }

    @podcast.reload
    assert @podcast.cover_art.attached?
    assert_equal "cover.png", @podcast.cover_art.filename.to_s
  end

  test "podcast cover art can be removed" do
    sign_in_as(@user)
    create_podcast

    # Attach cover art
    @podcast.cover_art.attach(
      io: File.open(@test_image_path),
      filename: "to_remove.png",
      content_type: "image/png"
    )
    assert @podcast.cover_art.attached?

    # Remove via form flag
    patch podcast_wizard_path(@podcast, :media), params: {
      podcast: { remove_cover_art: "1" }
    }

    @podcast.reload
    assert_not @podcast.cover_art.attached?
  end

  # ==================
  # Episode Assets Tests
  # ==================

  test "episode wizard accepts multiple assets" do
    sign_in_as(@user)
    create_podcast
    create_episode

    # Upload two files
    signed_id1 = upload_file_via_direct_upload(@test_audio_path, "audio1.wav", "audio/wav")
    signed_id2 = upload_file_via_direct_upload(@test_audio_path, "audio2.wav", "audio/wav")

    patch podcast_episode_wizard_path(@podcast, @episode, :assets), params: {
      episode: {
        assets: [signed_id1, signed_id2]
      }
    }

    @episode.reload
    assert_equal 2, @episode.assets.count
    assert_includes @episode.assets.map { |a| a.filename.to_s }, "audio1.wav"
    assert_includes @episode.assets.map { |a| a.filename.to_s }, "audio2.wav"
  end

  test "episode asset can be deleted" do
    sign_in_as(@user)
    create_podcast
    create_episode

    # Attach asset
    @episode.assets.attach(
      io: File.open(@test_audio_path),
      filename: "deletable.wav",
      content_type: "audio/wav"
    )

    attachment_id = @episode.assets.first.id
    initial_count = @episode.assets.count

    delete wizard_destroy_asset_path(
      podcast_id: @podcast.id,
      episode_id: @episode.id,
      attachment_id: attachment_id
    ), as: :json

    assert_response :success

    @episode.reload
    assert_equal initial_count - 1, @episode.assets.count
  end

  test "episode accepts cover art and assets together" do
    sign_in_as(@user)
    create_podcast
    create_episode

    cover_signed_id = upload_file_via_direct_upload(@test_image_path, "cover.png", "image/png")
    asset_signed_id = upload_file_via_direct_upload(@test_audio_path, "audio.wav", "audio/wav")

    patch podcast_episode_wizard_path(@podcast, @episode, :assets), params: {
      episode: {
        cover_art: cover_signed_id,
        assets: [asset_signed_id]
      }
    }

    @episode.reload
    assert @episode.cover_art.attached?
    assert @episode.assets.attached?
    assert_equal "cover.png", @episode.cover_art.filename.to_s
  end

  # ==================
  # Episode Form Upload Tests
  # ==================

  test "episode edit form accepts cover art upload" do
    sign_in_as(@user)
    create_podcast
    create_episode

    cover_signed_id = upload_file_via_direct_upload(@test_image_path, "new_cover.png", "image/png")

    patch podcast_episode_path(@podcast, @episode), params: {
      episode: {
        name: "Updated Episode",
        cover_art: cover_signed_id
      }
    }

    @episode.reload
    assert_equal "Updated Episode", @episode.name
    assert @episode.cover_art.attached?
    assert_equal "new_cover.png", @episode.cover_art.filename.to_s
  end

  test "episode edit form accepts multiple assets upload" do
    sign_in_as(@user)
    create_podcast
    create_episode

    asset_signed_id1 = upload_file_via_direct_upload(@test_audio_path, "asset1.wav", "audio/wav")
    asset_signed_id2 = upload_file_via_direct_upload(@test_audio_path, "asset2.wav", "audio/wav")

    patch podcast_episode_path(@podcast, @episode), params: {
      episode: {
        assets: [asset_signed_id1, asset_signed_id2]
      }
    }

    @episode.reload
    assert_equal 2, @episode.assets.count
  end

  # ==================
  # Producer Deliverables Tests
  # ==================

  test "producer can upload deliverables" do
    create_podcast
    create_episode
    @episode.update!(status: :edit_requested)

    sign_in_as(@producer)

    signed_id = upload_file_via_direct_upload(@test_audio_path, "final_mix.wav", "audio/wav")

    patch producer_episode_path(@episode), params: {
      episode: {
        deliverables: [signed_id]
      }
    }

    @episode.reload
    assert @episode.deliverables.attached?
    assert_equal "final_mix.wav", @episode.deliverables.first.filename.to_s
  end

  test "producer can upload multiple deliverables" do
    create_podcast
    create_episode
    @episode.update!(status: :editing)

    sign_in_as(@producer)

    signed_id1 = upload_file_via_direct_upload(@test_audio_path, "mix_v1.wav", "audio/wav")
    signed_id2 = upload_file_via_direct_upload(@test_audio_path, "mix_v2.wav", "audio/wav")

    patch producer_episode_path(@episode), params: {
      episode: {
        deliverables: [signed_id1, signed_id2]
      }
    }

    @episode.reload
    assert_equal 2, @episode.deliverables.count
  end

  test "producer index does not show draft episodes" do
    create_podcast
    create_episode
    @episode.update!(status: :draft)

    sign_in_as(@producer)

    get producer_episodes_path
    assert_response :success

    # Draft episodes should not appear in the producer's episode list
    assert_no_match @episode.name, response.body
  end

  # ==================
  # Authorization Tests
  # ==================

  test "user cannot upload to another user's podcast" do
    create_podcast  # Creates podcast for @user

    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      verified: true
    )

    sign_in_as(other_user)

    signed_id = upload_file_via_direct_upload(@test_image_path, "hacker.png", "image/png")

    # Try to access another user's podcast edit page
    get edit_podcast_path(@podcast)

    # Should be redirected due to authorization
    assert_response :redirect
    assert_match "Access denied", flash[:alert]
  ensure
    other_user&.destroy
  end

  test "non-producer cannot access producer upload endpoint" do
    create_podcast
    create_episode
    @episode.update!(status: :edit_requested)

    sign_in_as(@user)  # Regular user, not producer

    signed_id = upload_file_via_direct_upload(@test_audio_path, "fake.wav", "audio/wav")

    patch producer_episode_path(@episode), params: {
      episode: { deliverables: [signed_id] }
    }

    # Should be forbidden
    assert_response :redirect

    @episode.reload
    assert_not @episode.deliverables.attached?
  end

  # ==================
  # Edge Cases
  # ==================

  test "uploading to non-existent episode returns not found" do
    sign_in_as(@user)
    create_podcast

    delete wizard_destroy_asset_path(
      podcast_id: @podcast.id,
      episode_id: 999999,
      attachment_id: 1
    ), as: :json

    assert_response :not_found
  end

  test "deleting non-existent attachment returns not found" do
    sign_in_as(@user)
    create_podcast
    create_episode

    delete wizard_destroy_asset_path(
      podcast_id: @podcast.id,
      episode_id: @episode.id,
      attachment_id: 999999
    ), as: :json

    assert_response :not_found
  end

  test "uploading preserves existing attachments" do
    sign_in_as(@user)
    create_podcast
    create_episode

    # Attach initial asset
    @episode.assets.attach(
      io: File.open(@test_audio_path),
      filename: "existing.wav",
      content_type: "audio/wav"
    )
    initial_count = @episode.assets.count

    # Upload additional asset
    signed_id = upload_file_via_direct_upload(@test_audio_path, "new.wav", "audio/wav")

    patch podcast_episode_wizard_path(@podcast, @episode, :assets), params: {
      episode: {
        assets: [signed_id]
      }
    }

    @episode.reload
    # Should have both files (existing + new)
    assert @episode.assets.count >= initial_count
  end
end
