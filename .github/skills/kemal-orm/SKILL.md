---
name: kemal-orm
description: Object-Relational Mapping (ORM) with Crecto and SQLite in Kemal, following established project patterns.
---

# Kemal ORM Integration (Crecto)

This skill provides expert guidance on using Crecto ORM with Kemal applications and SQLite, strictly following patterns from `src/kemal-by-example/budget-management-orm/`.

## Compatibility Matrix

| Feature | Kemal 1.12.0 (Release) | Kemal Master (Unreleased / Next) |
| :--- | :--- | :--- |
| Crecto ORM (`crecto`) Integration | Supported | Supported |
| Crecto Adapters (`Crecto::Adapters::SQLite3`) | Supported | Supported |
| Declarative Schema, Validations & Queries | Supported | Supported |
| Centwise Integer Currency Handling | Supported | Supported |

## Core Mandates

- **Dependencies:** Include `kemal`, `crecto`, and `sqlite3` in `shard.yml` and `require` them in the main application file.
- **Repository Setup:** Centralize Crecto configuration in a `config/repo.cr` module:

  ```crystal
  module MyProject
    module Repo
      extend Crecto::Repo

      config do |conf|
        conf.adapter = Crecto::Adapters::SQLite3
        conf.db = ENV["DATABASE_URL"]? || "sqlite3:./db/app.db"
      end
    end
  end
  ```

- **Schema Initialization:** Set up database schema tables with `Repo.db_adapter.exec` in a `Schema.setup` module:

  ```crystal
  module MyProject
    module Schema
      extend self

      def setup
        Repo.db_adapter.exec <<-SQL
          CREATE TABLE IF NOT EXISTS budget_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            kind TEXT NOT NULL,
            amount_cents INTEGER NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            created_at DATETIME,
            updated_at DATETIME
          );
        SQL
      end
    end
  end
  ```

- **Model Definition:** Subclass `Crecto::Model`, declare fields inside `schema`, and set validation rules:

  ```crystal
  module MyProject
    class BudgetEntry < Crecto::Model
      schema "budget_entries" do
        field :title, String
        field :kind, String
        field :amount_cents, Int64
        field :notes, String
      end

      validate_required :title
      validate_inclusion :kind, %w[income expense]
    end
  end
  ```

- **Repository Operations:**
  - Querying all: `query = Crecto::Repo::Query.new.order_by("id DESC"); Repo.all(BudgetEntry, query)`
  - Finding by ID: `Repo.get(BudgetEntry, id)`
  - Creating: `entry = BudgetEntry.new; entry.title = title; Repo.insert(entry)`
  - Updating: `entry.title = new_title; Repo.update(entry)`
  - Deleting: `Repo.delete(entry)`

## Patterns from Source Code

### Repo Configuration (`config/repo.cr`)

```crystal
require "crecto"

module BudgetManagementOrm
  module Repo
    extend Crecto::Repo

    config do |conf|
      conf.adapter = Crecto::Adapters::SQLite3
      conf.db = ENV["DATABASE_URL"]? || "sqlite3:./db/budget.db"
    end
  end
end
```

### Schema Setup (`config/schema.cr`)

```crystal
require "./repo"

module BudgetManagementOrm
  module Schema
    extend self

    def setup
      Repo.db_adapter.exec <<-SQL
        CREATE TABLE IF NOT EXISTS budget_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          kind TEXT NOT NULL,
          amount_cents INTEGER NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          created_at DATETIME,
          updated_at DATETIME
        );
      SQL
    end
  end
end
```

### Model with Validations & Domain Logic (`models/budget_entry.cr`)

```crystal
require "../config/repo"

module BudgetManagementOrm
  class BudgetEntry < Crecto::Model
    schema "budget_entries" do
      field :title, String
      field :kind, String
      field :amount_cents, Int64
      field :notes, String
    end

    validate_required :title
    validate_inclusion :kind, %w[income expense]

    def income? : Bool
      kind == "income"
    end

    def expense? : Bool
      kind == "expense"
    end

    def self.all_ordered : Array(BudgetEntry)
      query = Crecto::Repo::Query.new.order_by("id DESC")
      Repo.all(BudgetEntry, query)
    end

    def self.find(id : Int64) : BudgetEntry?
      Repo.get(BudgetEntry, id)
    end

    def self.create(title : String, kind : String, notes : String, amount_cents : Int64)
      entry = BudgetEntry.new
      entry.title = title
      entry.kind = kind
      entry.notes = notes
      entry.amount_cents = amount_cents
      Repo.insert(entry)
    end

    def update_fields(title : String, kind : String, notes : String, amount_cents : Int64)
      self.title = title
      self.kind = kind
      self.notes = notes
      self.amount_cents = amount_cents
      Repo.update(self)
    end

    def destroy
      Repo.delete(self)
    end
  end
end
```

### Route Integration with Crecto Models (`routes/entries.cr`)

```crystal
get "/entries" do
  entries = BudgetManagementOrm::BudgetEntry.all_ordered
  render "src/views/entries/index.ecr", "src/views/layouts/application.ecr"
end

get "/entries/:id/edit" do |env|
  id = env.params.url["id"]?.try(&.to_i64?)
  entry = id ? BudgetManagementOrm::BudgetEntry.find(id) : nil

  if entry
    render "src/views/entries/edit.ecr", "src/views/layouts/application.ecr"
  else
    env.response.status = :not_found
    "Entry not found"
  end
end

post "/entries" do |env|
  title = env.params.body["title"]?.try(&.strip) || ""
  raw_kind = env.params.body["kind"]? || "expense"
  kind = raw_kind == "income" ? "income" : "expense"
  notes = env.params.body["notes"]?.try(&.strip) || ""
  cents = BudgetManagementOrm::Money.parse_cents(env.params.body["amount"]? || "")

  if !title.empty? && cents && cents > 0
    BudgetManagementOrm::BudgetEntry.create(title, kind, notes, cents)
  end

  env.redirect "/entries"
end

post "/entries/:id/delete" do |env|
  id = env.params.url["id"]?.try(&.to_i64?)
  entry = id ? BudgetManagementOrm::BudgetEntry.find(id) : nil
  entry.try(&.destroy)
  env.redirect "/entries"
end
```

## Best Practices

- **Centwise Currency Storage:** Always store monetary values as integers (`Int64` cents) to avoid floating-point rounding errors.
- **Repository Pattern:** Delegate database access to Crecto's `Repo` object rather than executing raw SQL strings directly in route handlers.
- **Model Validation:** Use `validate_required`, `validate_format`, and `validate_inclusion` inside model definitions for declarative data integrity.
- **Initialization Order:** Run `Schema.setup` in your main entrypoint file before calling `Kemal.run`.

## When to Use

- When building Kemal applications that require ORM abstraction (Crecto) instead of raw SQL strings.
- When organizing complex domain models with validations and relations.
- When managing structured database queries with ordering, filtering, and transactions.
