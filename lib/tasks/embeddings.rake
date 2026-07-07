namespace :embeddings do
  desc "Embed messages lacking a vector via local Ollama: bin/rails embeddings:backfill [TENANT=default]"
  task backfill: :environment do
    Tenant.find_by!(name: ENV.fetch("TENANT", "default")).switch do
      total = Message.missing_embedding.count
      puts "#{total} messages to embed with #{Ollama.embed_model}"
      done = Message.backfill_embeddings { |count| print "\r#{count}/#{total}" }
      puts "\nStored #{done} embeddings"
    end
  end
end
