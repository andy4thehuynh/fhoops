class ChatsController < ApplicationController
  PAGE_SIZE = 50

  def index
    @favorites = Contact.favorites
    @chats = Chat.includes(:contact).by_recency
    @chats = @chats.matching(params[:q]) if params[:q].present?
  end

  def show
    @chat = Chat.find(params[:id])

    newest_first = @chat.messages.includes(:attachments).reverse_chronological
    newest_first = newest_first.before(@chat.messages.find(params[:before])) if params[:before]

    page = newest_first.limit(PAGE_SIZE + 1).to_a
    @more = page.size > PAGE_SIZE
    @messages = page.first(PAGE_SIZE).reverse
  end
end
