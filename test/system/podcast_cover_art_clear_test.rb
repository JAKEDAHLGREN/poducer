require "application_system_test_case"

class PodcastCoverArtClearTest < ApplicationSystemTestCase
  setup do
    @user = users(:lazaro_nixon)
    visit sign_in_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "Secret1*3*5*"
    click_button "Continue"
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
    assert @podcast.cover_art.attached?

    visit podcast_wizard_path(@podcast, :media)

    # Preview should be visible; click the X
    assert_selector('button[title="Remove File"]', wait: 5)
    find('button[title="Remove File"]').click

    # Submit the step to persist removal
    click_button "Next"

    # Cover should be purged
    @podcast.reload
    assert_not @podcast.cover_art.attached?
  end

  test "clear cover art on Summary step and persist after Finish" do
    # Re-attach so we can clear again
    @podcast.cover_art.attach(
      io: StringIO.new("another fake"),
      filename: "again.png",
      content_type: "image/png"
    )
    @podcast.save!
    assert @podcast.cover_art.attached?

    visit podcast_wizard_path(@podcast, :summary)

    # Preview should be visible; click the X
    assert_selector('button[title="Remove File"]', wait: 5)
    find('button[title="Remove File"]').click

    # Persist via Finish
    if has_button?("Finish Podcast")
      click_button "Finish Podcast"
    else
      click_button "Update Podcast"
    end

    @podcast.reload
    assert_not @podcast.cover_art.attached?
  end
end
