class EpisodesController < ApplicationController
  before_action :set_podcast
  before_action :set_episode, only: [ :show, :edit, :update, :destroy, :submit_episode, :start_editing, :complete_editing, :publish_episode, :revert_to_draft ]
  before_action :authorize_access_to_episode, only: [ :show, :edit, :update, :destroy, :submit_episode, :start_editing, :complete_editing, :publish_episode, :revert_to_draft ]
  before_action :authorize_editing, only: [ :edit, :update ]

  def index
    @episodes = Current.user.admin? ? @podcast.episodes : @podcast.episodes.where(user: Current.user)
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
    # Only allow editing if episode is in draft or edit_requested status
    unless @episode.draft?
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Cannot edit episode while it's being edited by a producer."
    end
  end

  def update
    # Only allow updating if episode is in draft or edit_requested status
    unless @episode.draft?
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Cannot edit episode while it's being edited by a producer."
    end

    if @episode.update(episode_params)
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    redirect_to podcast_episodes_path(@podcast), notice: "Episode was successfully deleted."
  end

  def submit_episode
    if @episode.submit_for_editing!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode submitted for editing successfully."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to submit episode for editing."
    end
  end

  def revert_to_draft
    if @episode.revert_to_draft!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode reverted to draft successfully."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to revert episode to draft."
    end
  end

  def start_editing
    if @episode.start_editing!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Started editing episode."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to start editing episode."
    end
  end

  def complete_editing
    if @episode.complete_editing!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode editing completed."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to complete episode editing."
    end
  end

  def publish_episode
    if @episode.update(status: :episode_complete) # Use the correct status
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode published successfully."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to publish episode."
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_episode
    @episode = @podcast.episodes.find(params[:id])
  end

  def episode_params
    params.require(:episode).permit(:name, :number, :description, :links, :release_date, :format, :notes, :raw_audio, :edited_audio, :assets, :cover_art)
  end

  def authorize_access_to_episode
    redirect_to podcast_episodes_path(@podcast), alert: "Access denied." unless Current.user.admin? || @episode.podcast.user == Current.user
  end

  def authorize_editing
    # Users can only edit their own episodes
    # Producers can edit any episode (for now)
    if Current.user.user?
      redirect_to podcast_episodes_path(@podcast), alert: "Access denied." unless @episode.podcast.user == Current.user
    end
  end
end
