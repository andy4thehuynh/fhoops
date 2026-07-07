# Hybrid search over the archive. Keyword search decrypts and scans in
# Ruby — encrypted bodies can't be matched in SQL, and under 100k messages
# that's perfectly fine. Semantic search embeds the query locally and asks
# sqlite-vec for neighbors. Ask mode is retrieval THEN generation, kept
# separate so search still works when generation is disabled (GEN_MODEL="").
module Search
  KEYWORD_LIMIT = 25
  TOP_K = 10
  BATCH = 500

  Answer = Data.define(:text, :sources)

  class << self
    def chats(query)
      Chat.includes(:contact).matching(query)
    end

    def keyword(query, limit: KEYWORD_LIMIT)
      needle = query.downcase
      results = []
      offset = 0

      loop do
        batch = Message.includes(chat: :contact).reverse_chronological.limit(BATCH).offset(offset).to_a
        break if batch.empty?

        batch.each do |message|
          results << message if results.size < limit && message.body.to_s.downcase.include?(needle)
        end
        break if results.size >= limit

        offset += BATCH
      end

      results
    end

    def semantic(query, k: TOP_K)
      Message.nearest(Ollama.embed(query), limit: k)
    rescue Faraday::Error
      [] # Ollama unreachable — keyword results still stand.
    end

    def generation_enabled?
      Ollama.gen_model.present?
    end

    # RAG: the top semantic matches become the model's only context, and the
    # answer cites them by number.
    def ask(query)
      sources = semantic(query, k: TOP_K)
      return nil if sources.empty?

      Answer.new(text: Ollama.generate(prompt_for(query, sources)), sources: sources)
    rescue Faraday::Error
      nil
    end

    private
      def prompt_for(query, sources)
        context = sources.map.with_index(1) do |message, number|
          from = message.is_from_me ? "Me" : message.chat.contact.display_name
          "[#{number}] #{from}, #{message.sent_at.to_date}: #{message.body.presence || message.embedding_text}"
        end.join("\n")

        <<~PROMPT
          You are answering questions about a personal iMessage archive.
          Use ONLY the messages below. Cite the message numbers you used in
          square brackets. If the messages don't contain the answer, say so.

          Messages:
          #{context}

          Question: #{query}

          Answer:
        PROMPT
      end
  end
end
