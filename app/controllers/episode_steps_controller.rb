class EpisodeStepsController < ApplicationController
  include Wicked::Wizard
  steps :overview, :assets, :details, :summary

  before_action :set_podcast
  before_action :set_episode
  before_action :set_steps
  before_action -> { authorize_resource_access(@episode) }

  def show
    session.delete(:validation_errors)
    render_wizard
  end

  # PATCH /podcasts/:podcast_id/episodes/:episode_id/wizard/assets
  def assets
    # Accept either files[] or single file (some browsers/controllers may send 'file')
    incoming = params[:files].presence || params[:file].presence
    unless incoming
      respond_to do |format|
        format.json { render json: { error: "No files provided" }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end
    Array(incoming).each do |file|
      @episode.assets.attach(file)
    end
    respond_to do |format|
      format.json { render json: { ok: true, count: @episode.assets.count }, status: :ok }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "current_assets",
            partial: "episode_steps/current_assets",
            locals: { episode: @episode }
          ),
          turbo_stream.replace(
            "summary_assets",
            partial: "episode_steps/summary_assets",
            locals: { episode: @episode, podcast: @podcast }
          )
        ]
      end
      format.html { redirect_to podcast_episode_wizard_path(@podcast, @episode, :summary), notice: "Assets uploaded." }
    end
  end

  # PATCH /podcasts/:podcast_id/episodes/:episode_id/wizard/raw_audio
  def raw_audio
    # Accept either file or files[]
    file = params[:file].presence || Array(params[:files]).first
    unless file.present?
      return render json: { error: "No file provided" }, status: :unprocessable_entity
    end
    @episode.raw_audio.purge_later if @episode.raw_audio.attached?
    @episode.raw_audio.attach(file)
    render json: { ok: true, filename: @episode.raw_audio.filename.to_s }, status: :ok
  end

  # DELETE /podcasts/:podcast_id/episodes/:episode_id/wizard/assets/:attachment_id
  def destroy_asset
    attachment = @episode.assets.attachments.find_by(id: params[:attachment_id])
    unless attachment
      respond_to do |format|
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.turbo_stream { head :not_found }
        format.html { redirect_to podcast_episode_wizard_path(@podcast, @episode, :summary), alert: "Asset not found." }
      end
      return
    end
    attachment.purge_later
    respond_to do |format|
      format.json { render json: { ok: true }, status: :ok }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "current_assets",
            partial: "episode_steps/current_assets",
            locals: { episode: @episode }
          ),
          turbo_stream.replace(
            "summary_assets",
            partial: "episode_steps/summary_assets",
            locals: { episode: @episode, podcast: @podcast }
          )
        ]
      end
      format.html do
        redirect_to podcast_episode_wizard_path(@podcast, @episode, :summary), notice: "Asset deleted."
      end
    end
  end

  # DELETE /podcasts/:podcast_id/episodes/:episode_id/wizard/raw_audio
  def destroy_raw_audio
    if @episode.raw_audio.attached?
      @episode.raw_audio.purge_later
    end
    render json: { ok: true }, status: :ok
  end

  def update
    session.delete(:validation_errors)

    # (reverted) no JSON upload handling here

    if params[:episode].present?
      filtered_params = episode_params

      # Prevent blank file inputs from purging existing attachments
      filtered_params = filtered_params.except(:assets) if filtered_params[:assets]&.all?(&:blank?)
      filtered_params = filtered_params.except(:raw_audio) if filtered_params[:raw_audio].blank?
      filtered_params = filtered_params.except(:cover_art) if filtered_params[:cover_art].blank?
      # Clear cover art if requested
      if params[:episode][:remove_cover_art].to_s == "1"
        @episode.cover_art.purge_later if @episode.cover_art.attached?
      end
      # Preserve existing episode number if the user leaves it blank
      filtered_params = filtered_params.except(:number) if filtered_params.key?(:number) && filtered_params[:number].to_s.strip.blank?
      # Join output formats array into a comma-separated string for storage
      if filtered_params[:output_formats].is_a?(Array)
        filtered_params[:output_formats] = filtered_params[:output_formats].reject(&:blank?).join(",")
      end

      @episode.assign_attributes(filtered_params) if filtered_params.present?
    end

    # Auto-assign the next available episode number on finalization if missing
    if step == :summary && @episode.number.blank?
      next_number = (@podcast.episodes.where.not(id: @episode.id).maximum(:number) || 0) + 1
      @episode.number = next_number
    end

    valid =
      case step
      when :overview
        @episode.valid?(:overview_step)
      when :details
        @episode.valid?(:details_step)
      when :summary
        # On summary, ensure required fields from earlier steps are valid
        @episode.valid?(:overview_step) & @episode.valid?(:details_step)
      else
        true
      end

    if valid
      if @episode.save(validate: false)
        # Optional: Update asset labels when provided
        if params[:asset_labels].present?
          labels = params[:asset_labels].to_unsafe_h rescue params[:asset_labels]
          Array(@episode.assets.attachments).each do |attachment|
            label_value = labels[attachment.id.to_s] || labels[attachment.blob.id.to_s]
            next if label_value.nil?
            begin
              new_metadata = attachment.blob.metadata.merge("label" => label_value.to_s.strip)
              attachment.blob.update!(metadata: new_metadata)
            rescue => _
              # Silently ignore metadata update errors for now
            end
          end
        end

        if step == steps.last
          redirect_to_finish_wizard
        else
          redirect_to next_wizard_path
        end
      else
        render step
      end
    else
      session[:validation_errors] = @episode.errors.full_messages
      render step
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_episode
    @episode = @podcast.episodes.find(params[:episode_id])
  end

  def set_steps
    @steps = steps
  end

  def episode_params
    params.require(:episode).permit(
      :name,
      :number,
      :description,
      :links,
      :release_date,
      :format,
      :notes,
      :guests,
      :output_formats,
      :deliver_mp3,
      :deliver_mp4,
      :deliver_mov,
      :raw_audio,
      :cover_art,
      assets: [],
      output_formats: []
    )
  end

  def redirect_to_finish_wizard
    redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode created successfully."
  end
end
