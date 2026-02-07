module SetPodcastAndEpisode
  extend ActiveSupport::Concern

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_episode
    episode_id = params[:episode_id] || params[:id]
    @episode = @podcast.episodes.find(episode_id)
  end
end
