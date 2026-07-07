class CreateArchive < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.string :handle, null: false, index: { unique: true }
      t.string :display_name
      t.boolean :favorite, null: false, default: false
      t.integer :favorite_position, index: { unique: true }

      t.timestamps
    end

    create_table :chats do |t|
      t.belongs_to :contact, null: false, foreign_key: true, index: { unique: true }
      t.string :name

      t.timestamps
    end

    create_table :messages do |t|
      t.belongs_to :chat, null: false, foreign_key: true
      t.boolean :is_from_me, null: false, default: false
      t.string :service
      t.string :guid, null: false, index: { unique: true }
      t.text :body
      t.datetime :sent_at, index: true

      t.timestamps
    end

    create_table :attachments do |t|
      t.belongs_to :message, null: false, foreign_key: true
      t.string :filename
      t.string :mime_type
      t.integer :byte_size
      t.text :path

      t.timestamps
    end
  end
end
