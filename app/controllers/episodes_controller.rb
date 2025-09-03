class EpisodesController < ApplicationController
  before_action :set_podcast
  before_action :set_episode, only: [:show, :edit, :update, :destroy]

  def index
    @episodes = @podcast.episodes
  end

  def new
    @episode = @podcast.episodes.build
  end

  def create
    @episode = @podcast.episodes.build(episode_params)
    if @episode.save
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @episode.update(episode_params)
      redirect_to podcast_episode_path(@podcast, @episode), notice: 'Episode was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    redirect_to podcast_episodes_path(@podcast), notice: 'Episode was successfully deleted.'
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_episode
    @episode = @podcast.episodes.find(params[:id])
  end

  def episode_params
    params.require(:episode).permit(:name, :number, :description, :links, :release_date, :format, :notes, :raw_audio, :edited_audio, :assets)
  end
end
