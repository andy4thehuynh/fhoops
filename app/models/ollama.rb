# The only door to the LLM. Everything runs against a local Ollama on the
# host — message content never leaves the box. Retrieval (embed) and
# generation are deliberately separate: search keeps working with
# generation disabled (GEN_MODEL="").
module Ollama
  class << self
    def embed(text)
      connection.post("/api/embeddings", { model: embed_model, prompt: text }).body.fetch("embedding")
    end

    def generate(prompt)
      connection.post("/api/generate", { model: gen_model, prompt: prompt, stream: false }).body.fetch("response")
    end

    def embed_model
      ENV.fetch("EMBED_MODEL", "nomic-embed-text")
    end

    def gen_model
      ENV.fetch("GEN_MODEL", "llama3.1:8b")
    end

    def url
      ENV.fetch("OLLAMA_URL", "http://localhost:11434")
    end

    def connection
      @connection ||= Faraday.new(url) do |f|
        f.request :json
        f.response :json
        f.response :raise_error
        f.options.timeout = 120
      end
    end

    # Test seam.
    attr_writer :connection
  end
end
