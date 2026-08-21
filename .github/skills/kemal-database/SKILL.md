---
name: kemal-database
description: Database initialization and interaction with SQLite and raw SQL in Kemal, following established project patterns.
license: MIT
---

# Kemal Database Integration

This skill provides expert guidance on integrating SQLite databases with Kemal using the `db` and `sqlite3` shards, strictly following patterns from [`kemal-by-example`](https://github.com/sdogruyol/kemal-by-example).

## Core Mandates

- **Dependencies:** Always `require "db"` and `require "sqlite3"` in the main application file. Add them to `shard.yml`.
- **Connection:** Centralize the database connection in a `config/database.cr` file. Use environment variables for the URL:

  ```crystal
  module MyProject
    module Database
      extend self
      DATABASE_URL = ENV["DATABASE_URL"]? || "sqlite3:./db/database.db"

      @@mutex = Mutex.new
      @@connection : DB::Database? = nil

      def connection : DB::Database
        @@connection || @@mutex.synchronize { @@connection ||= DB.open(DATABASE_URL) }
      end
    end
  end
  ```

- **Schema Setup:** Use a `Schema.setup` method to run `CREATE TABLE IF NOT EXISTS` statements:

  ```crystal
  module MyProject
    module Schema
      extend self

      def setup
        Database.connection.exec <<-SQL
          CREATE TABLE IF NOT EXISTS items (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        SQL
      end
    end
  end
  ```

- **Model Mapping:** Use `include DB::Serializable` in models for automatic mapping from SQL results:

  ```crystal
  class Item
    include DB::Serializable
    property id : Int64?
    property name : String
    property created_at : String
  end
  ```

- **Data Retrieval:** Use `query_all` and `query_one?` with the `as: Class` argument:
  - `Database.connection.query_all("SELECT * FROM items", as: Item)`
  - `Database.connection.query_one?("SELECT * FROM items WHERE id = ?", id, as: Item)`

## Patterns from Source Code

### Database Module Pattern (All Projects)

```crystal
# config/database.cr
module Blog
  module Database
    extend self

    DATABASE_URL = ENV["DATABASE_URL"]? || "sqlite3:./db/blog.db"

    @@mutex = Mutex.new
    @@connection : DB::Database? = nil

    def connection : DB::Database
      @@connection || @@mutex.synchronize { @@connection ||= DB.open(DATABASE_URL) }
    end
  end
end
```

### Schema Setup with Multiple Tables

```crystal
# config/schema.cr
module Ecommerce
  module Schema
    extend self

    def setup
      Database.connection.exec <<-SQL
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      SQL

      Database.connection.exec <<-SQL
        CREATE TABLE IF NOT EXISTS products (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          price_cents INTEGER NOT NULL,
          inventory_count INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      SQL
    end
  end
end
```

### Model with DB::Serializable

```crystal
# models/post.cr
class Post
  include DB::Serializable

  getter id : Int64?
  getter title : String
  getter body : String
  getter created_at : String
  getter updated_at : String

  def initialize(
    @title : String,
    @body : String,
    @id : Int64? = nil,
    @created_at : String = Time.utc.to_s,
    @updated_at : String = Time.utc.to_s,
  )
  end

  def self.all : Array(Post)
    Blog::Database.connection.query_all(
      "SELECT id, title, body, created_at, updated_at FROM posts ORDER BY created_at DESC",
      as: Post
    )
  end

  def self.find(id : Int64) : Post?
    Blog::Database.connection.query_one?(
      "SELECT id, title, body, created_at, updated_at FROM posts WHERE id = ?",
      id,
      as: Post
    )
  end

  def self.create(title : String, body : String) : Post
    now = Time.utc.to_s
    # `Database.connection` is a pooled `DB::Database`: a separate
    # `SELECT last_insert_rowid()` may run on a different connection and return
    # the wrong id. Read the id from the `DB::ExecResult` of the INSERT itself.
    result = Blog::Database.connection.exec(
      "INSERT INTO posts (title, body, created_at, updated_at) VALUES (?, ?, ?, ?)",
      title,
      body,
      now,
      now
    )
    id = result.last_insert_id
    find(id) || raise "Failed to load post ##{id} after creation"
  end

  def update(title : String, body : String)
    Blog::Database.connection.exec(
      "UPDATE posts SET title = ?, body = ?, updated_at = ? WHERE id = ?",
      title,
      body,
      Time.utc.to_s,
      @id
    )
  end

  def delete
    Blog::Database.connection.exec(
      "DELETE FROM posts WHERE id = ?",
      @id
    )
  end
end
```

### Initialization in Main File

```crystal
# blog.cr
require "kemal"
require "db"
require "sqlite3"

require "./config/database"
require "./config/schema"
require "./models/post"
require "./routes/home"
require "./routes/posts"

Blog::Schema.setup
Kemal.run
```

## Best Practices

- **Initialization:** Call `Schema.setup` before `Kemal.run` in the main application file.
- **Timestamps:** Always use `Time.utc.to_s` for storing `created_at` and `updated_at` as `TEXT` in SQLite.
- **ID Handling:** Use `Int64?` for IDs to accommodate auto-incrementing fields during creation.
- **Transactions:** Use `Database.connection.transaction do |tx| ... end` for atomic operations.
- **SQL Execution:** Use `Database.connection.exec("SQL", args)` for insert, update, and delete operations.
- **Explicit Column Lists:** List all columns explicitly in SELECT statements rather than using `SELECT *`.

## When to Use

- When setting up a new database or modifying an existing schema.
- When implementing model methods that interact with the database.
- When configuring database connections and initialization logic.
