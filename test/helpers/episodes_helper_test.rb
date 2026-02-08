require "test_helper"

class EpisodesHelperTest < ActionView::TestCase
  include EpisodesHelper

  test "draft badge displays Draft" do
    assert_match "Draft", episode_status_badge("draft")
  end

  test "edit_requested badge displays Edit Requested" do
    assert_match "Edit Requested", episode_status_badge("edit_requested")
  end

  test "editing badge displays Editing" do
    assert_match "Editing", episode_status_badge("editing")
  end

  test "awaiting_user_review badge displays Awaiting Your Review" do
    assert_match "Awaiting Your Review", episode_status_badge("awaiting_user_review")
  end

  test "ready_to_publish badge displays Ready to Publish" do
    assert_match "Ready to Publish", episode_status_badge("ready_to_publish")
  end

  test "episode_complete badge displays Episode Complete" do
    assert_match "Episode Complete", episode_status_badge("episode_complete")
  end

  test "archived badge displays Archived" do
    assert_match "Archived", episode_status_badge("archived")
  end

  test "unknown status falls back to humanized string" do
    assert_match "Some unknown status", episode_status_badge("some_unknown_status")
  end
end
