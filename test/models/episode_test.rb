require "test_helper"

class EpisodeTest < ActiveSupport::TestCase
  setup do
    @episode = episodes(:one)
    @episode.update_column(:status, Episode.statuses[:draft])
  end

  # === Valid Transitions ===

  test "submit_for_editing transitions from draft to edit_requested" do
    @episode.submit_for_editing!
    assert @episode.edit_requested?
  end

  test "revert_to_draft transitions from edit_requested to draft" do
    @episode.update_column(:status, Episode.statuses[:edit_requested])
    @episode.revert_to_draft!
    assert @episode.draft?
  end

  test "start_editing transitions from edit_requested to editing" do
    @episode.update_column(:status, Episode.statuses[:edit_requested])
    @episode.start_editing!
    assert @episode.editing?
  end

  test "complete_editing transitions from editing to awaiting_user_review" do
    @episode.update_column(:status, Episode.statuses[:editing])
    @episode.complete_editing!
    assert @episode.awaiting_user_review?
  end

  test "re_submit_for_editing transitions from awaiting_user_review to edit_requested" do
    @episode.update_column(:status, Episode.statuses[:awaiting_user_review])
    @episode.re_submit_for_editing!
    assert @episode.edit_requested?
  end

  test "approve_episode transitions from awaiting_user_review to ready_to_publish" do
    @episode.update_column(:status, Episode.statuses[:awaiting_user_review])
    @episode.approve_episode!
    assert @episode.ready_to_publish?
  end

  test "publish transitions from ready_to_publish to episode_complete" do
    @episode.update_column(:status, Episode.statuses[:ready_to_publish])
    @episode.publish!
    assert @episode.episode_complete?
  end

  test "archive transitions from any state to archived" do
    @episode.archive!
    assert @episode.archived?
  end

  # === Invalid Transitions ===

  test "submit_for_editing fails from editing" do
    @episode.update_column(:status, Episode.statuses[:editing])
    result = @episode.submit_for_editing!
    assert_equal false, result
    assert @episode.editing?
  end

  test "revert_to_draft fails from draft" do
    result = @episode.revert_to_draft!
    assert_equal false, result
    assert @episode.draft?
  end

  test "start_editing fails from draft" do
    result = @episode.start_editing!
    assert_equal false, result
    assert @episode.draft?
  end

  test "complete_editing fails from draft" do
    result = @episode.complete_editing!
    assert_equal false, result
    assert @episode.draft?
  end

  test "re_submit_for_editing fails from draft" do
    result = @episode.re_submit_for_editing!
    assert_equal false, result
    assert @episode.draft?
  end

  test "approve_episode fails from draft" do
    result = @episode.approve_episode!
    assert_equal false, result
    assert @episode.draft?
  end

  test "publish fails from draft" do
    result = @episode.publish!
    assert_equal false, result
    assert @episode.draft?
  end

  # === Output Format Helpers ===

  test "output_formats_list parses comma-separated string" do
    @episode.output_formats = "MP3 128kbps, WAV, FLAC"
    assert_equal [ "MP3 128kbps", "WAV", "FLAC" ], @episode.output_formats_list
  end

  test "output_formats_list returns empty array when blank" do
    @episode.output_formats = nil
    assert_equal [], @episode.output_formats_list

    @episode.output_formats = ""
    assert_equal [], @episode.output_formats_list
  end

  test "output_formats_list= joins array into comma-separated string" do
    @episode.output_formats_list = [ "MP3 128kbps", "WAV" ]
    assert_equal "MP3 128kbps,WAV", @episode.output_formats
  end

  test "output_formats_list= strips whitespace and rejects blanks" do
    @episode.output_formats_list = [ " MP3 128kbps ", "", " WAV ", nil ]
    assert_equal "MP3 128kbps,WAV", @episode.output_formats
  end

  # === Status Query Methods ===

  test "can_be_edited_by_producer? returns true for edit_requested and editing" do
    @episode.update_column(:status, Episode.statuses[:edit_requested])
    assert @episode.can_be_edited_by_producer?

    @episode.update_column(:status, Episode.statuses[:editing])
    assert @episode.can_be_edited_by_producer?

    @episode.update_column(:status, Episode.statuses[:draft])
    assert_not @episode.can_be_edited_by_producer?
  end

  test "can_be_submitted_by_user? returns true only for draft" do
    assert @episode.can_be_submitted_by_user?

    @episode.update_column(:status, Episode.statuses[:editing])
    assert_not @episode.can_be_submitted_by_user?
  end

  test "is_editing_in_progress? returns true only for editing" do
    @episode.update_column(:status, Episode.statuses[:editing])
    assert @episode.is_editing_in_progress?

    @episode.update_column(:status, Episode.statuses[:draft])
    assert_not @episode.is_editing_in_progress?
  end

  test "is_complete? returns true only for episode_complete" do
    @episode.update_column(:status, Episode.statuses[:episode_complete])
    assert @episode.is_complete?

    @episode.update_column(:status, Episode.statuses[:draft])
    assert_not @episode.is_complete?
  end

  # === Validations ===

  test "overview_step requires name and description" do
    @episode.name = nil
    @episode.description = nil
    assert_not @episode.valid?(:overview_step)
    assert_includes @episode.errors[:name], "can't be blank"
    assert_includes @episode.errors[:description], "can't be blank"
  end

  test "details_step requires notes" do
    @episode.notes = nil
    assert_not @episode.valid?(:details_step)
    assert_includes @episode.errors[:notes], "can't be blank"
  end

  # === Association + Constants ===

  test "belongs to podcast" do
    assert_respond_to @episode, :podcast
    assert_instance_of Podcast, @episode.podcast
  end

  test "constants are frozen" do
    assert Episode::FORMAT_OPTIONS.frozen?
    assert Episode::OUTPUT_FORMAT_OPTIONS.frozen?
  end
end
