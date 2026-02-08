require "application_system_test_case"

class PodcastCoverArtClearTest < ApplicationSystemTestCase
  # Disable parallel execution for system tests to avoid database isolation issues
  parallelize(workers: 1)

  setup do
    @user = users(:lazaro_nixon)
    visit sign_in_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "Secret1*3*5*"
    click_button "Continue"
    assert_current_path podcasts_path
    # Ensure we have a podcast owned by this user
    @podcast = Podcast.create!(
      user: @user,
      name: "Test Podcast",
      description: "Desc",
      primary_category: "Technology",
      status: :draft
    )
    # Attach a fake cover so we can test clearing
    @podcast.cover_art.attach(
      io: StringIO.new("fake image bytes"),
      filename: "cover.png",
      content_type: "image/png"
    )
    @podcast.save!
  end

  test "clear cover art on Media step and persist after Next" do
    visit podcast_wizard_path(@podcast, :media)

    # Cover art file should be listed
    assert_selector('button[title="Remove file"]', wait: 5)

    # Click remove and accept the confirm dialog
    accept_confirm do
      find('button[title="Remove file"]').click
    end

    # After JS removes the file, the file list should show empty state
    assert_text "No files uploaded yet."

    # Submit the step
    click_button "Next"

    # Go back to media step and verify cover art is gone
    visit podcast_wizard_path(@podcast, :media)
    assert_no_selector('button[title="Remove file"]')
    assert_text "No files uploaded yet."
  end

  test "clear cover art on Summary step and persist after Finish" do
    visit podcast_wizard_path(@podcast, :summary)

    # Cover art file should be listed
    assert_selector('button[title="Remove file"]', wait: 5)

    # Click remove and accept the confirm dialog
    accept_confirm do
      find('button[title="Remove file"]').click
    end

    # After JS removes the file, the file list should show empty state
    assert_text "No files uploaded yet."

    # Submit the step
    if has_button?("Finish Podcast")
      click_button "Finish Podcast"
    else
      click_button "Update Podcast"
    end

    # Should redirect to podcasts page after finishing
    assert_current_path podcasts_path
  end
end
