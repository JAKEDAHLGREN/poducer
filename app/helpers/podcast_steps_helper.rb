module PodcastStepsHelper
  EPISODE_TYPES = {
    episodic: "Episodic",
    serial: "Serial"
  }

  def episode_type_options
    EPISODE_TYPES.map { |key, value| [ value, key.to_s ] }
  end
end
