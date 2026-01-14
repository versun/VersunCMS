# Comment Reply Email Notification Design

Date: 2026-01-14

## Goal

Send a reply notification email to the parent commenter **only after the reply is approved**, using the existing native email (SMTP) configuration. The email content is bilingual (Chinese + English), and self-replies (same email) are skipped.

## Trigger & Scope

- Triggered when a **reply comment** transitions to `approved`.
- Applies to **local comments only** (`platform` is `nil`).
- Requires `parent_id` and `parent.author_email` to be present.
- **Skip self-replies** when `reply.author_email` matches parent email (case-insensitive).
- Use an `after_commit` hook on `Comment` to enqueue a job after approval.

## Data Flow

1. Comment status changes to `approved`.
2. `Comment` `after_commit` checks eligibility and enqueues `CommentReplyNotificationJob`.
3. Job revalidates eligibility, loads newsletter settings.
4. If native email is enabled and configured, apply SMTP settings and send `CommentMailer.reply_notification`.
5. Record events via `Rails.event.notify`; raise errors to allow job retries.

## Email Content

- Subject: `你收到一条新的回复 | New reply to your comment | <site title>`
- Body includes:
  - Reply author name
  - Reply content
  - Original comment excerpt (short)
  - Article/Page title and link
- HTML + plain text templates.
- Link built from `Setting.url` (normalized) + article/page path; falls back to relative path if missing.

## Error Handling

- Missing parent email / missing parent / self-reply: **skip quietly**.
- Email not configured (native disabled or incomplete): **skip quietly**.
- SMTP or delivery error: **log and raise** to allow retry.

## Tests

- Enqueues job when reply is approved.
- Sends email to parent on approval (with configured native email).
- Skips sending for self-replies.

## Files to Touch

- `app/models/comment.rb` (after_commit enqueue)
- `app/jobs/comment_reply_notification_job.rb` (new)
- `app/mailers/comment_mailer.rb` (new)
- `app/views/comment_mailer/reply_notification.html.erb` (new)
- `app/views/comment_mailer/reply_notification.text.erb` (new)
- `test/models/comment_test.rb` (enqueue behavior)
- `test/jobs/comment_reply_notification_job_test.rb` (send/skip)
- `test/mailers/comment_mailer_test.rb` (content)

