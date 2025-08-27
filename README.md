# README

# Poducer

A podcast production and organization application.

## Description

A SaaS web application that allows podcast content creators to upload and manage audio and video recordings, request them to be produced, and access the finished product after being produced by a third party.

### Users

There are three types of users:

- **Client**: The person/people that upload raw, unedited media and request its production. These are the end users.  
- **Producer**: The people that fulfill the production requests from podcasters and upload the finished production.  
- **Admin**: These are the highest level people that have access to account management, access control, and similar governing actions.  

---

## Tech Stack

This project is built with **Ruby on Rails 8.0** using Hotwire and Tailwind CSS.

### Core Framework
- Ruby on Rails 8.0
- SQLite (development/test), with support for Postgres in production
- Puma web server

### Frontend
- Hotwire (Turbo + Stimulus) for reactive UI
- Tailwind CSS (via `tailwindcss-rails`) for styling
- Importmap for managing JavaScript dependencies (no Node required)

### Authentication & Authorization
- [authentication-zero](https://github.com/lazaronixon/authentication-zero) for user authentication (email + password)
- Role-based authorization (client, producer, admin)

### Background Jobs, Cache & Websockets
- `solid_queue` for background jobs
- `solid_cache` for caching
- `solid_cable` for ActionCable/WebSocket support

### Development & Tooling
- `letter_opener` for previewing emails in development
- `brakeman` for security analysis
- `rubocop-rails-omakase` for linting
- `debug` and `web-console` for debugging


## Database Schema (Initial)

```mermaid
erDiagram
  User {
    integer id PK
    string email
    string password_digest
    integer role
    integer plan
    datetime created_at
    datetime updated_at
  }

  Podcast {
    integer id PK
    integer user_id FK
    string name
    text description
    string website_url
    string primary_category
    string secondary_category
    string tertiary_category
    integer status
    datetime created_at
    datetime updated_at
  }

  Episode {
    integer id PK
    integer podcast_id FK
    string name
    integer number
    text links
    date release_date
    text description
    text notes
    string format
    integer status
    datetime created_at
    datetime updated_at
  }

  User ||--o{ Podcast: "hosts"
  Podcast ||--o{ Episode: "has"


## Running the Project

### Prerequisites
- Ruby 3.3+
- Rails 8.0
- SQLite (for development/test) or PostgreSQL (for production)
- Redis (if using caching or ActionCable in production)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/JAKEDAHLGREN/poducer.git
   cd poducer
2. **Install dependencies**
   bundle install
3. **Set up the database**
   bin/rails db:setup
4. **Run the server**
   bin/dev
