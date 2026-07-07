class SearchesController < ApplicationController
  def show
    @query = params[:q].to_s.strip
    @mode = params[:mode] == "ask" && Search.generation_enabled? ? "ask" : "search"
    return if @query.blank?

    @chats = Search.chats(@query)
    @keyword_matches = Search.keyword(@query)
    @semantic_matches = Search.semantic(@query)
    @answer = Search.ask(@query) if @mode == "ask"
  end
end
