# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rables is a Rails 8.1 personal blog system with article management, social media crossposting, email newsletters, and static site generation. Uses SQLite for all databases (primary, cache, queue, cable).

## Common Commands

```bash
# Development server
bin/rails server

# Database
bin/rails db:migrate
bin/rails db:seed

# Tests
bin/rails test                    # Run all tests
bin/rails test test/models/       # Run model tests
bin/rails test test/models/article_test.rb  # Single test file
bin/rails test test/models/article_test.rb:42  # Single test at line

# Static site generation
bin/rails static:generate         # Full generation (assets + HTML)
bin/rails static:html_only        # HTML only, no asset compilation
bin/rails static:clean            # Clean generated files

# Assets
bin/rails assets:precompile
bin/rails assets:clobber

# Code quality
bin/rubocop                       # Linting
bin/brakeman                      # Security scan

# Background jobs (Solid Queue)
bin/rails jobs:work               # Process jobs
```

## Architecture

### Content Model
- **Article**: Main content type with rich text (ActionText) or HTML content. Supports statuses: draft, publish, schedule, trash, shared. Has tags, comments, and social media posts.
- **Page**: Static pages with similar structure to articles
- **Tag**: Categorization with slugs, supports subscriber notifications

### Static Site Generation
`StaticGenerator` (app/models/static_generator.rb) generates a complete static site:
- Outputs to `public/` (local) or `tmp/static_output/` (GitHub deploy)
- Exports ActiveStorage images to `/uploads/` with compression
- Replaces ActiveStorage URLs with static paths in HTML/RSS
- Generates index pages with pagination, article pages, tag pages, RSS feed, sitemap

### Social Media Integration
Located in `app/services/services/` (`Services::*` namespace):
- **TwitterService**: X/Twitter posting with media upload
- **MastodonService**: Mastodon posting
- **BlueskyService**: Bluesky posting with rich text facets
- **InternetArchiveService**: URL archiving
- **GithubDeployService**: Deploy static site to GitHub Pages

### Background Jobs (Solid Queue)
Key jobs in `app/jobs/`:
- `CrosspostArticleJob`: Post to social platforms
- `GenerateStaticFilesJob`: Async static generation with GitHub deploy
- `NativeNewsletterSenderJob`: Send newsletters to subscribers
- `FetchSocialCommentsJob`: Import comments from social posts
- `PublishScheduledArticlesJob`: Auto-publish scheduled articles

### Admin Interface
All admin routes under `/admin/` namespace. Key controllers handle:
- Article/Page CRUD with batch operations
- Comment moderation (approve/reject)
- Settings, newsletter config, crosspost config
- Static file management, redirects
- Import/Export (WordPress, RSS, ZIP)

### Key Models
- `Setting`: Site-wide configuration (singleton pattern via `first_or_create`)
- `Subscriber`: Newsletter subscribers with tag-based subscriptions
- `Redirect`: URL redirect rules with regex support
- `StaticFile`: User-uploaded files for static hosting

### Frontend
- Uses Hotwire (Turbo + Stimulus)
- Importmap for JS modules
- Lexxy gem for rich text editor
- Two CSS variants: `application.css` (full) and `static.css` (no Trix editor styles)

### Storage
- ActiveStorage with local disk or S3 (configurable)
- Static files served from `storage/static/` or via StaticFile records
