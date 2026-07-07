class CreateMessageEmbeddings < ActiveRecord::Migration[8.1]
  # 768 dimensions = nomic-embed-text. Brute-force cosine KNN via sqlite-vec
  # is plenty below 100k messages.
  def up
    execute "CREATE VIRTUAL TABLE IF NOT EXISTS message_embeddings USING vec0(message_id INTEGER PRIMARY KEY, embedding float[768] distance_metric=cosine)"
  end

  def down
    execute "DROP TABLE message_embeddings"
  end
end
