# Implementation Plan: AI Content Creation Assistant ("Content Buddy AI")

**Input**: `specs/001-ai-content-assistant/spec.md` (all FR-xxx references below are defined there)
**Status**: Draft — ready for `tasks.md` breakdown
**Scope guardrail**: every item below either adds new files or makes a small, additive change to an existing file. Nothing in this plan renames, restructures, or changes the behavior of existing routes, screens, or tables.

---

## 1. Design Constraints (from the existing codebase, not invented)

Pulled from `CLAUDE.md` and direct inspection (`specs/001-ai-content-assistant/spec.md` §0), because a plan that ignores house conventions gets rejected in review:

- **Flat file layout, no feature folders.** New Flutter files go directly under `lib/` as one file per screen/service, matching `podcast.dart`, `podcast_service.dart`, etc. — not a new `lib/ai/` subfolder.
- **No state-management library.** Where mutable state needs to be shared across widgets (recording state, in-flight generation), use a `ChangeNotifier` singleton — the same pattern `PodcastPlayerController` already establishes — not Provider/Bloc/Riverpod.
- **No model classes; plain `Map<String, dynamic>`.** `PodcastService`/`EBookService` explicitly avoid model classes per `CLAUDE.md`. This plan follows suit for conversations/messages/saved content.
- **Theming via `context.textColor` / `context.cardBg` / etc.** (the `ThemeContext` extension at the bottom of `main.dart`). No new theming mechanism.
- **admin-app is a single-file Express server with routes inline.** This plan adds a `routes/`, `services/`, `middleware/` split for the *new* AI surface only — existing routes in `server.js` are not touched beyond one `app.use(...)` mount line. (A structural split is unavoidable here: this feature has ~10 endpoints and 6 services; inlining that into the existing 1150-line `server.js` would make the diff far harder to review than a few new files.)

### Deliberate deviation from convention — and why

`CLAUDE.md` says new Supabase-backed features should "talk directly to Supabase via `supabase_flutter`" like `PodcastService`/`EBookService` do. **This feature does not follow that pattern for conversations/messages/saved content — those go through new `admin-app` REST endpoints instead.** Reason: the Claude API key must never reach the mobile app (FR-043), which already forces a backend round-trip for every generation call. Once that round-trip exists, giving conversation/message/saved-content CRUD a second, inconsistent access path (direct-Supabase for reads, backend for writes) is more complex than routing all of it through the same backend, and it lets the backend enforce per-user ownership in application code (FR-046) rather than relying on Supabase Row-Level-Security tied to `auth.uid()` — which doesn't work here anyway, since there is no real Supabase Auth session (§0 of the spec). This is called out explicitly rather than silently diverging from the documented pattern.

**Single-vendor constraint**: per stakeholder direction, Claude is the *only* AI/cloud service this feature calls — no OpenAI, no second vendor anywhere in the stack, including for speech-to-text (§2).

## 2. Resolved-decisions recap (see spec.md §6 for full rationale)

| Decision | Value |
|---|---|
| Speech-to-text | **On-device** (Android `SpeechRecognizer` / iOS `Speech`, via Flutter's `speech_to_text` package) — no cloud vendor, no OpenAI, audio never leaves the phone |
| User identity | Existing anonymous per-device UUID (same `shared_preferences` key convention as Podcast/E-books) |
| Daily usage limit | 30 generations / user / rolling 24h |
| Rate limit | 10 requests / user / minute |
| Max recording length | 3 minutes |
| Max image upload | 8MB raw → compressed to ≤2MB / ≤1600px longest edge before send |
| Backend auth scope | New `aiUsageGuard` middleware on `/api/ai/**` only; existing admin-app routes untouched |
| Image retention | Persisted indefinitely in Supabase Storage, cascade-deleted with the owning conversation |
| Voice retention | N/A — audio is never transmitted or stored anywhere; on-device only |
| Claude model | Env-configurable (`CLAUDE_MODEL`), non-streaming v1; Stop = client aborts the HTTP request |

## 3. Integration point (not specified by the stakeholder — decided here)

The original prompt never says *where in the app* users open this feature. Given the Home page's 6-card quick-access grid has just been through several rounds of pixel-precise, explicitly-locked-down changes (exact 6 cards, exact colors) in this same app, adding a 7th card there is exactly the kind of unrelated-screen change the spec's FR-041 forbids. The existing side drawer menu (`main.dart`, the list currently containing Home Feed / TBT Leaderboard / Community Feed / Courses Path / Course Quest / Voice of Sakthi / E-Book Library / Notifications / Logout) is the app's existing "list of major modules" surface and already grows by one line per new module — that's the intended entry point:

- **One new drawer menu item**, e.g. "Content Buddy AI", positioned next to "Voice of Sakthi" / "E-Book Library", opening `AIContentScreen`.

If the stakeholder wants a different entry point (FAB, profile tab, etc.), that's a one-line change to make later — flagging it here so it isn't buried in a diff.

## 4. Data Model

New Supabase tables (new file `admin-app/ai_schema.sql`, matching the existing `podcast_schema.sql` / `ebook_schema.sql` convention):

```sql
create table ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  title text not null default 'New Conversation',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_ai_conversations_user on ai_conversations(user_id, updated_at desc);

create table ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references ai_conversations(id) on delete cascade,
  sender text not null check (sender in ('user','assistant')),
  message text not null,
  input_type text not null check (input_type in ('text','voice','image')),
  image_url text,
  content_type text,
  language text,
  tone text,
  created_at timestamptz not null default now()
);
create index idx_ai_messages_conversation on ai_messages(conversation_id, created_at);

create table saved_ai_content (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  conversation_id uuid references ai_conversations(id) on delete set null,
  title text not null,
  content text not null,
  category text not null default 'other'
    check (category in ('social_media','advertisement','business','personal','video_script','email','other')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_saved_ai_content_user on saved_ai_content(user_id, created_at desc);

-- In-memory in v1 (see aiUsageGuard); table kept for a future persistent/multi-instance upgrade.
create table ai_usage_counters (
  user_id text not null,
  window_type text not null check (window_type in ('day','minute')),
  window_start timestamptz not null,
  count integer not null default 0,
  primary key (user_id, window_type, window_start)
);
```

Supabase Storage: new bucket `ai-content`, object path `ai-content/{user_id}/{conversation_id}/{message_id}.{ext}` (mirrors the existing `community/podcast/...` path convention already used by `/api/upload`).

## 5. Backend (`admin-app/`)

### New files

| File | Responsibility |
|---|---|
| `services/claudeService.js` | Builds the system prompt (spec §"System Prompt for Claude", stored as a constant here) + message history, calls `https://api.anthropic.com/v1/messages` via native `fetch`, handles text-only and text+image (base64) payloads, maps timeouts/errors to typed error codes the route layer turns into the friendly messages from spec FR-035. **Only outbound AI/cloud call in the whole backend** — no speech-to-text service exists here at all; transcription is on-device (§2). |
| `services/imageUploadService.js` | Validates type (JPG/JPEG/PNG/WEBP) + size, compresses via `sharp` to the §6.3 target, uploads to the `ai-content` Storage bucket, returns the public URL. Reuses the multer-memory-storage pattern from the existing `/api/upload` route. |
| `services/conversationService.js` | CRUD for `ai_conversations` + `ai_messages`: create conversation, append message, list (paginated, most-recent-first), rename, delete (cascades messages + storage images), search by title. Title is generated for free: on a conversation's *first* turn, the `content/create` request to Claude also asks for a ≤5-word title as a bracketed line in the same response (parsed server-side, not shown to the user) — avoids a second paid API call just for a title. |
| `services/savedContentService.js` | CRUD + search for `saved_ai_content`. |
| `services/usageLimitService.js` | In-memory sliding counters per user for the day/minute windows (§2 table); exposes `checkAndConsume(userId) -> { allowed, remaining, resetAt }`. |
| `middleware/aiUsageGuard.js` | Requires a `user_id` on every request, calls `usageLimitService`, returns `429` with a machine-readable `reason` (`rate_limited` \| `daily_limit_reached`) the mobile client maps to the spec's friendly copy. Mounted only on the AI router. |
| `routes/ai.js` | All `/api/ai/**` endpoints (contract in §6 below). Thin — validates input shape, delegates to services, shapes the JSON response. |
| `ai_schema.sql` | Schema in §4, at the `admin-app/` root next to the existing `*_schema.sql` files. |
| `.env.example` | New — none currently exists. Documents `SUPABASE_URL`, `SUPABASE_KEY`, `PORT` (existing) plus the new `ANTHROPIC_API_KEY`, `CLAUDE_MODEL`. **No `OPENAI_API_KEY` or any second vendor key** — Claude is the only external AI service this backend calls. Committed (unlike `.env`) so setup instructions are self-contained. |

### Modified files

| File | Change |
|---|---|
| `server.js` | Add `const aiRouter = require('./routes/ai'); const aiUsageGuard = require('./middleware/aiUsageGuard'); app.use('/api/ai', aiUsageGuard, aiRouter);` — a 3-line addition near the other route mounts. No existing route touched. |
| `package.json` | Add one new dependency: `sharp` (image compression — nothing else needed; the Claude call uses Node's built-in `fetch`, already available in the installed Node 24 runtime, so no HTTP client or `@anthropic-ai/sdk` dependency is added either). |

## 6. API Contract

All routes are namespaced under `/api/ai` and pass through `aiUsageGuard` (except read-only history/saved-content listing, which still requires `user_id` for ownership scoping but doesn't count against the generation quota).

| Method & Path | Purpose |
|---|---|
| `POST /api/ai/content/create` | Main generation endpoint (spec's original contract, extended — see below) |
| `GET /api/ai/conversations?user_id=&search=` | List a user's conversations, most-recent-first |
| `GET /api/ai/conversations/:id/messages?user_id=` | Full message history for one conversation (ownership-checked) |
| `PATCH /api/ai/conversations/:id` | Rename (`{ user_id, title }`) |
| `DELETE /api/ai/conversations/:id?user_id=` | Delete conversation + messages + associated Storage images |
| `GET /api/ai/saved?user_id=&category=&search=` | List/search saved content |
| `POST /api/ai/saved` | Save a piece of generated content |
| `PATCH /api/ai/saved/:id` | Edit title/content/category (`{ user_id, ... }`) |
| `DELETE /api/ai/saved/:id?user_id=` | Delete a saved item |

`POST /api/ai/content/create` accepts `multipart/form-data` (not pure JSON) so it can carry an optional image in the same request as the structured fields — avoiding a separate upload-then-reference round trip:

- `payload` (form field, JSON-encoded string): matches the spec's example —
  ```json
  {
    "message": "Create a funny Instagram caption for a coffee shop",
    "inputType": "text",
    "contentType": "instagram_caption",
    "tone": "funny",
    "language": "thanglish",
    "length": "medium",
    "conversationId": "uuid-or-null",
    "userId": "anonymous-device-uuid"
  }
  ```
- `image` (form field, optional file): raw image bytes, validated/compressed by `imageUploadService` before being sent to Claude's vision input.

Response (unchanged from the stakeholder's spec, `suggestions` populated from the quick-action set in FR-027 filtered to what's contextually relevant):
```json
{
  "success": true,
  "conversationId": "uuid",
  "content": "Generated AI response",
  "suggestions": ["Make it shorter", "Add emojis", "Make it more professional"]
}
```

Error shape (consistent across all endpoints, mapped by the mobile client to the FR-035 friendly messages):
```json
{ "success": false, "code": "daily_limit_reached", "message": "..." }
```
Backend `code` values: `empty_input`, `invalid_image_type`, `image_too_large`, `daily_limit_reached`, `rate_limited`, `claude_timeout`, `claude_error`, `not_found`, `forbidden`, `server_error`. (`transcription_failed` is a **client-side-only** condition now — on-device recognition either succeeds or the mobile app surfaces it directly; it never reaches the backend, since audio never does.)

## 7. Mobile (`lib/`)

### New files

| File | Responsibility |
|---|---|
| `ai_content_service.dart` | Singleton (`AIContentService.instance`), plain `Map<String, dynamic>` returns — mirrors `PodcastService`/`EBookService` shape even though it calls `admin-app` REST endpoints instead of Supabase directly (§1 deviation). Owns the same anonymous-UUID read/write logic as the existing services (small, deliberate duplication — consistent with how `PodcastService`/`EBookService` each already own their own copy, rather than introducing a new shared identity module as an unrelated refactor). |
| `ai_recording_controller.dart` | `ChangeNotifier` singleton (same shape as `PodcastPlayerController`) wrapping the `speech_to_text` package: idle/listening/paused/stopped state, duration ticker, `speech_to_text`'s sound-level callback drives the waveform, enforces the 3-minute cap client-side. **Owns transcription itself** — `speech_to_text` streams recognized text directly from the OS recognizer, so there's no separate "recording → file → upload → transcribe" pipeline and no audio file ever exists on disk to clean up. |
| `ai_content_screen.dart` | The chat screen: header, welcome state + suggestion cards, message list (auto-scroll), text input + mic + image-attach + send, per-response action row, quick-action chips, Stop button (aborts the in-flight request). |
| `ai_chat_history_screen.dart` | List/search/rename/delete conversations; tapping one opens `ai_content_screen.dart` pre-loaded with its history. |
| `ai_saved_content_screen.dart` | List/search/category-filter saved items; copy/share/edit/delete. |

### Modified files

| File | Change |
|---|---|
| `pubspec.yaml` | Add `speech_to_text: ^7.x` (on-device recognition + duration/sound-level, no OpenAI/cloud vendor — nothing already installed does this) and `permission_handler: ^11.x` (explicit mic-permission flow + the required denial message, FR-005; `speech_to_text` triggers the OS prompt but this gives control over the custom denial copy). Both are new capabilities — nothing already installed does this. |
| `main.dart` | One new drawer menu item ("Content Buddy AI") next to the existing module list, routing to `AIContentScreen` — see §3. No other line in `main.dart` changes. |

## 8. Loading / Error Copy Wiring

The Thanglish loading/error strings from the spec are static UI copy in `ai_content_screen.dart`, selected by request phase (`sending` / `analyzing_image` / `transcribing`) and by the backend's `code` field on failure — no backend involvement beyond returning the `code`, keeping all user-facing copy (and any future language changes to it) on the client.

## 9. Implementation Phases (sequencing for `tasks.md`)

1. **Phase A — Backend foundation.** `ai_schema.sql`, Storage bucket, all `services/*.js`, `middleware/aiUsageGuard.js`, `routes/ai.js`, `server.js` mount line, `.env.example`. Testable end-to-end with `curl`/Postman before any Flutter work starts.
2. **Phase B — Mobile service layer.** `ai_content_service.dart` only, smoke-tested against Phase A with temporary debug output — no UI yet.
3. **Phase C — Chat UI, text-first.** `ai_content_screen.dart` with text input/send/response bubbles/quick-actions working end-to-end. Image and voice input added after text is solid, since text is the simplest path and everything else layers on top of the same send pipeline.
4. **Phase D — Image input.** Attach/preview/remove, compression, vision-grounded responses.
5. **Phase E — Voice input.** `ai_recording_controller.dart`, permission flow, waveform UI, transcription review-before-send.
6. **Phase F — History & saved content.** `ai_chat_history_screen.dart`, `ai_saved_content_screen.dart`, drawer entry point.
7. **Phase G — Polish & full test pass.** Loading/error copy, accessibility labels, responsive QA, the 26-item checklist from spec §7, `flutter analyze` + any admin-app lint, final changed/new-file report.

## 10. Progress Tracking

- [x] spec.md complete, clarifications resolved
- [x] plan.md complete
- [x] tasks.md complete — see `specs/001-ai-content-assistant/tasks.md` (T001–T047)
- [ ] Phase A–G implementation — not started; no application code has been written for this feature yet

---

*This plan adds new files almost everywhere by design — the two "modified" existing files (`server.js`, `main.dart`) each change by a handful of lines. Nothing here alters an existing route, screen, table, or theme.*
