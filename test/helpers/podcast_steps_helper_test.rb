require "test_helper"

class PodcastStepsHelperTest < ActionView::TestCase
  include PodcastStepsHelper

  test "episode_type_options returns correct pairs" do
    expected = [["Episodic", "episodic"], ["Serial", "serial"]]
    assert_equal expected, episode_type_options
  end
end
