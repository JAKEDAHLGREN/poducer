class Producer::EpisodesController < ApplicationController
  before_action :ensure_producer
  before_action :set_episode, only: [ :show, :start_editing, :complete_editing, :update ]

  def index
    # Show all episodes that need producer attention
    @episodes = Episode.includes(:podcast, podcast: :user)
                      .where(status: [ :edit_requested, :editing ])
                      .order(created_at: :desc)

    # Group by status for better organization
    @edit_requested_episodes = @episodes.select { |ep| ep.status == "edit_requested" }
    @editing_episodes = @episodes.select { |ep| ep.status == "editing" }
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
