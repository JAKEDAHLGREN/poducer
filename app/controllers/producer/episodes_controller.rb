class Producer::EpisodesController < ApplicationController
  before_action :ensure_producer
  before_action :set_episode, only: [ :show, :start_editing, :complete_editing, :update ]

  def index
    @episodes = Episode.includes(:podcast, podcast: :user).where(status: [ :edit_requested, :editing, :awaiting_user_review, :ready_to_publish ]).order(updated_at: :desc)

    @edit_requested_episodes = @episodes.select(&:edit_requested?)
    @editing_episodes = @episodes.select(&:editing?)
    @awaiting_user_review_episodes = @episodes.select(&:awaiting_user_review?)
    @ready_to_publish_episodes = @episodes.select(&:ready_to_publish?)
  end

  def show
    # Show episode details for producer
  end

  def update
    # Allow producer to upload edited audio and update episode
    if @episode.update(episode_params)
      redirect_to producer_episode_path(@episode), notice: "Episode updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def start_editing
    if @episode.start_editing!
      redirect_to producer_episode_path(@episode), notice: "Started editing episode."
    else
      redirect_to producer_episodes_path, alert: "Unable to start editing episode."
    end
  end

  def complete_editing
    if @episode.complete_editing!
      redirect_to producer_episodes_path, notice: "Episode editing completed."
    else
      redirect_to producer_episode_path(@episode), alert: "Unable to complete episode editing."
    end
  end

  private

  def set_episode
    @episode = Episode.find(params[:id])
  end

  def episode_params
    params.require(:episode).permit(:edited_audio, :notes)
  end
end
