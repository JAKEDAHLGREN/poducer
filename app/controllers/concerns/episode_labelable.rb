# Convenience wrappers for persisting episode asset/cover-art labels to blob metadata.
# Delegates to BlobLabelable for the shared implementation.
# Include in any controller that updates episodes and submits label params.
module EpisodeLabelable
  extend ActiveSupport::Concern
  include BlobLabelable

  private

  def process_episode_asset_labels(episode)
    process_blob_labels(episode, :assets, label_key: :asset_labels)
  end

  def process_episode_cover_art_label(episode)
    process_single_blob_label(episode, :cover_art, label_key: :cover_art_labels)
  end
end
