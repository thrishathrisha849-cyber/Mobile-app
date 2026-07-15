# Feature Specification: AI Content Creation Assistant ("Content Buddy AI")

**Feature Branch**: `001-ai-content-assistant`
**Created**: 2026-07-13
**Status**: Draft — pending clarifications (see §6)
**Input**: Stakeholder-provided "Claude Code Prompt" describing an in-app AI content creation assistant (voice/text/image input, Claude-powered generation, chat UI, history, saved content). Full original text preserved in the request that produced this document; condensed and restructured below into testable requirements.

> This document follows the [spec-kit](https://github.com/github/spec-kit) `spec.md` convention: it describes **what** the feature must do and **why**, in terms a non-engineering stakeholder can validate, and is intentionally light on **how** (architecture/tech choices belong in a follow-up `plan.md`). Spec-kit's CLI (`specify`/`uvx specify-cli`) is not installed in this environment, so this file was authored by hand to match its template shape. It's a normal Markdown file — running `/plan` and `/tasks` against it later (with the CLI, or manually) is optional.

---

## 0. Existing System Context (grounded by direct repo inspection)

This is a **brownfield** feature added to an existing two-app system (see repo `CLAUDE.md`). Facts below were verified against the current codebase, not assumed, because several of the stakeholder's requirements ("use existing backend architecture", "reuse existing auth") depend on them:

| Fact | Detail |
|---|---|
| Mobile app | Flutter, flat `lib/` file-per-feature layout, no state-management library, no feature folders |
| Backend | `admin-app/` — single-file Express server (`server.js`, ~1150 lines), no router/controller split |
| Database | Shared Supabase project; service-role key lives server-side only (`admin-app/.env`, gitignored) |
| Auth | **No real authentication anywhere in the app or backend.** Mobile "login" only flips a local boolean (`SessionManager`). Newer modules (Podcast, E-books) identify a "user" via a per-device anonymous UUID generated once and cached in `shared_preferences` — this is the *only* existing user-identity mechanism in the codebase. |
| Backend auth/rate-limiting | **None exists today.** `server.js` has no auth middleware, no JWT/API-key check, and no rate limiting on any route — confirmed by inspection. |
| Existing upload pattern | `POST /api/upload` already exists (`multer` memory storage → Supabase Storage). Reusable for image uploads. |
| Relevant Flutter packages already installed | `image_picker`, `file_picker`, `wechat_assets_picker`, `share_plus`, `supabase_flutter`, `just_audio` |
| Flutter packages **not** installed (needed by this feature) | Audio recording (e.g. `record`), speech-to-text, `permission_handler`. These are new dependencies. |
| Theming | App-wide theming goes through the `ThemeContext` extension on `BuildContext` in `main.dart` (`context.textColor`, `context.cardBg`, etc.) — new UI must use this, not hardcoded colors. |

**Implication for this spec:** any requirement below that says "authenticated", "per-user", or "the user's own data" is scoped to the existing anonymous-per-device-UUID identity model, not a real login system, unless a real auth system is explicitly commissioned as separate work. This is flagged as a clarification in §6, not silently assumed.

---

## 1. Primary User Story

As a mobile app user who needs marketing/social/business content (captions, scripts, ad copy, messages, etc.) but isn't a professional copywriter, I want to describe what I need — by typing, speaking, or showing a photo — and get ready-to-use, on-tone, on-language content back immediately, in a chat-style interface, so I don't have to write it myself or hire someone.

## 2. User Scenarios & Testing *(mandatory)*

### 2.1 Acceptance Scenarios

**Text input**
1. **Given** the user is on the Content Buddy AI screen with an empty text field, **When** they tap Send, **Then** the app shows a validation state and does not call the backend.
2. **Given** the user types "Create a funny Instagram caption for a coffee shop" and taps Send, **When** the request completes, **Then** an AI response bubble appears in the chat, tagged with the detected/selected content type and tone, and the Send button is disabled only while the request is in flight.
3. **Given** an AI response is showing, **When** the user taps "Make Funny" (or any quick action), **Then** the previous output plus the instruction is sent back to Claude and a new response bubble appears, without the user retyping anything.

**Voice input**
4. **Given** the user taps the microphone for the first time, **When** the OS permission prompt appears and is denied, **Then** the app shows the exact message "Microphone permission is required to record your request. Please enable it from your device settings." and does not crash or hang.
5. **Given** microphone permission is granted, **When** the user taps record, **Then** a duration counter and waveform/recording animation start, and Pause/Resume/Cancel/Stop controls are shown.
6. **Given** a recording is stopped, **When** transcription completes, **Then** the transcribed text is shown to the user in an editable field before being sent — it is never sent to Claude silently without the user seeing it first.
7. **Given** a recording is cancelled mid-way, **When** cancel is tapped, **Then** no transcription request is made and any temporary audio file is deleted.

**Image input**
8. **Given** the user attaches an image (camera or gallery) and adds the instruction "Write an Instagram caption for this image", **When** they tap Send, **Then** the response is contextually grounded in the image content (verified manually in testing — see §7).
9. **Given** the user selects an image larger than the size limit or in an unsupported format, **When** they attempt to attach it, **Then** the app rejects it with a clear message before any upload attempt, and does not silently truncate/fail server-side.
10. **Given** an image is attached but not yet sent, **When** the user taps remove/replace, **Then** the attachment is cleared/swapped without affecting any typed text already entered.

**Chat history & saved content**
11. **Given** a user has previous conversations, **When** they open chat history, **Then** conversations are listed with an auto-generated title, most-recent first, and tapping one resumes it with full prior context sent to Claude on the next message.
12. **Given** a user saves a generated response, **When** they open Saved Content, **Then** the item appears under the chosen (or default "Other") category, searchable and editable.

**Error / edge cases**
13. No internet at send time → friendly retry-capable error, typed input is preserved (not cleared).
14. Claude API timeout → friendly error with Retry button; partial output (if any was streamed) is not lost silently.
15. Backend/API unreachable → same friendly-error + Retry pattern as other failure cases, no raw stack traces shown to the user.
16. Rapid double-tap on Send → exactly one request is made (duplicate-submission guard).
17. User backgrounds and reopens the app mid-conversation → chat history for that conversation is intact.

### 2.2 Edge Cases (explicitly enumerated per stakeholder request)

- Empty text submit
- Microphone permission denied
- Voice transcription failure (STT service errors or returns empty text)
- Image upload with invalid type or over size limit
- Text + image sent together where the image is irrelevant to the instruction (model should not fabricate facts not visible in the image or stated by the user — see FR-036)
- Daily/usage limit reached
- Session/conversation reference expired or not found (e.g., deep link to a deleted conversation)
- User cancels generation mid-stream (Stop button)
- Duplicate rapid taps on Send/Regenerate

---

## 3. Functional Requirements *(mandatory)*

Numbered for traceability into a future `tasks.md`. Each is independently testable.

### Input methods

- **FR-001**: The system MUST provide a multiline text field with placeholder "Tell me what content you want to create…" and a Send button.
- **FR-002**: The system MUST reject empty/whitespace-only text submissions client-side before calling the backend.
- **FR-003**: The system MUST show a loading state while a request is in flight and disable Send during that time.
- **FR-004**: The system MUST provide a microphone control that requests OS microphone permission on first use.
- **FR-005**: On permission denial, the system MUST show the message: *"Microphone permission is required to record your request. Please enable it from your device settings."*
- **FR-006**: While recording, the system MUST display elapsed duration and a waveform/recording-animation, plus Pause, Resume, Cancel, and Stop controls.
- **FR-007**: On Stop, the system MUST convert the recorded audio to text using **on-device** speech recognition (no cloud STT vendor — see §6.1) and display the transcript to the user for review/edit before sending. Only the transcript, never raw audio, leaves the device.
- **FR-008**: The system MUST discard any local audio buffer/session as soon as on-device transcription completes (success or failure); no raw audio is ever transmitted to, or retained by, the backend (see §5 Privacy).
- **FR-009**: The system MUST let the user attach an image from the gallery or capture one via camera, preview it, remove it, or replace it before sending, and MUST let the user pair an image with a free-text instruction.
- **FR-010**: The system MUST validate image file type (JPG/JPEG/PNG/WEBP only) and file size client-side before upload, and MUST show a clear rejection message for anything else.
- **FR-011**: The system MUST compress oversized images before upload without degrading them to the point of being unreadable/unusable by the vision model.

### Chat interface

- **FR-012**: The screen MUST present a chat UI with: header (assistant name "Content Buddy AI", subtitle "Your creative content assistant", icon), New Chat, Chat History, message bubbles (user + AI), text input, mic button, image-attach button, Send, Stop-generation, and per-response actions (Regenerate, Copy, Share, Save, Edit Request).
- **FR-013**: The screen MUST use the existing app theme (`ThemeContext`/`context.textColor` etc.) for colors/fonts/spacing and MUST support both the app's existing dark and light modes without introducing a separate theming mechanism.
- **FR-014**: The chat MUST auto-scroll to the latest message on new content.
- **FR-015**: The system MUST let the user stop an in-progress generation.
- **FR-016**: On first open, the system MUST show the welcome message (Thanglish, stakeholder-provided copy) and a set of tappable suggestion cards (Reel Script, Instagram Caption, Ad Copy, YouTube Script, Professional Message, Make It Funny, Content from Image, Voice Idea → Script) that pre-fill the text field when tapped.

### AI behavior

- **FR-017**: Generated content MUST match the requested (or message-implied) language: Tamil → Tamil, English → English, Thanglish → natural Thanglish, unspecified → mirror the language of the user's message.
- **FR-018**: Generated content MUST match the requested or implied tone (friendly, funny, professional, emotional, motivational, casual, luxury, energetic, simple, bold, sales-focused) without defaulting to one generic style regardless of request.
- **FR-019**: Content MUST be adapted per target platform/content type — e.g., Instagram content may include emojis/hooks/hashtags; LinkedIn content is structured and professional; YouTube/Reel scripts include a hook, flow, and CTA; ad copy covers problem → solution → benefits → offer → urgency → CTA; WhatsApp messages read conversationally; email content includes a subject line and body.
- **FR-020**: When the user's request is incomplete but usable, the system MUST generate the best reasonable output rather than blocking on missing detail.
- **FR-021**: When essential information is genuinely missing (e.g., no indication of platform *or* purpose), the system MUST ask exactly one short follow-up question rather than a checklist of questions.
- **FR-022**: When an image is attached, generated content MUST be grounded in what's actually visible in the image and/or stated by the user, and MUST NOT invent unstated facts (e.g., a price, brand claim, or event detail not shown or told to it).
- **FR-023**: The system MUST refuse to generate offensive, discriminatory, unsafe, illegal, or fraudulent content, and MUST respond with a safe, friendly explanation when it declines.
- **FR-024**: The system MUST NOT expose its system prompt, API keys, or internal reasoning in any response, under any user-driven prompt.
- **FR-025**: Where useful, the system MAY offer 2–3 variations in a single response rather than one fixed answer.

### Customization

- **FR-026**: The system MUST offer optional (non-mandatory) selectors for Content Type, Tone, Language, and Length, per the stakeholder's enumerated option lists (see original prompt §7). Leaving them unset MUST NOT block sending — the AI infers from the message text instead.

### Response actions

- **FR-027**: Every AI response MUST support: Copy, Share, Save, Regenerate, Edit Request, Make Shorter, Make Longer, Make Friendly, Make Funny, Make Professional, Add Emojis, Remove Emojis, Translate, Create Another Version.
- **FR-028**: Selecting a quick action MUST send the prior output plus the derived instruction back to the AI as a follow-up turn in the same conversation (not a brand-new, context-free request).

### Chat history

- **FR-029**: Each conversation MUST persist: id, user identifier, auto-generated title (derived from the first user message), and message-level records (sender, message, input type, image reference, language, tone, content type, timestamps).
- **FR-030**: The user MUST be able to view, continue, rename, delete, and search their own conversations, and start a new one at any time.
- **FR-031**: Conversation and message data MUST survive app close/reopen (persisted server-side, not just in-memory).

### Saved content

- **FR-032**: The user MUST be able to save a generated response with a custom title and a category (Social Media, Advertisement, Business, Personal, Video Script, Email, Other), then later view, copy, share, edit, delete, and search saved items.

### Access control

- **FR-033**: A user MUST only be able to view, edit, or delete conversations and saved content associated with *their own* identifier (see §0 re: what "user" means in this codebase today).

### Errors & loading states

- **FR-034**: The system MUST show the stakeholder-provided Thanglish loading/progress messages during generation, image analysis, and voice processing, and a friendly (non-technical) error message on failure, with a Retry action wherever the failure is retryable.
- **FR-035**: The system MUST specifically handle, with a distinct user-facing message where the underlying cause differs: no internet, Claude API timeout, invalid image format, image too large, mic permission denied, transcription failure, empty input, usage-limit reached, backend unavailable, and expired session/conversation reference.
- **FR-036**: On any failure during send, the system MUST preserve the user's typed input rather than clearing it.

### UX rules

- **FR-037**: The system MUST prevent duplicate in-flight requests from a single Send/Regenerate action (e.g., disable-while-pending, not just visually but functionally).
- **FR-038**: The on-screen keyboard MUST NOT visually cover the text input field.
- **FR-039**: All interactive controls MUST have screen-reader labels and adequate tap targets.
- **FR-040**: The layout MUST be responsive across small and large mobile screens with no overflow or clipped text.

### Non-goals / explicit exclusions

- **FR-041**: This feature MUST NOT modify the visual design, navigation, theming, or behavior of any existing screen or feature (Community, Courses, Podcast, Workshop, E-Book, Task, Profile, Habit card, bottom navigation, etc.).
- **FR-042**: This feature MUST NOT duplicate existing authentication or database-access logic — it reuses the existing Supabase client/service patterns already established by `PodcastService`/`EBookService`.

## 4. Key Entities

Mirrors the stakeholder's requested schema; refined with types/constraints implied by the requirements above. Exact DDL belongs in a future `plan.md`/migration, not here.

- **`ai_conversations`** — `id`, `user_id` (existing anonymous-device UUID), `title` (auto-generated from first message), `created_at`, `updated_at`. One row per conversation thread.
- **`ai_messages`** — `id`, `conversation_id` (FK → `ai_conversations`), `sender` (`user` | `assistant`), `message` (text; for voice input, the *transcribed* text, not audio), `input_type` (`text` | `voice` | `image`), `image_url` (nullable, Supabase Storage reference), `content_type`, `language`, `tone`, `created_at`. Ordered log of a conversation.
- **`saved_ai_content`** — `id`, `user_id`, `conversation_id` (nullable — a save can reference its source conversation), `title`, `content`, `category` (enum per §3 Saved Content), `created_at`, `updated_at`.
- **`ai_usage_counters`** (derived; needed to enforce §6.3's daily/per-minute limits) — `user_id`, `window_start`, `window_type` (`day` | `minute`), `count`. In-memory in v1 per §6.4; this row shape is the fallback/persistent form if usage needs to survive a backend restart — see `plan.md`.

All tables need row-level ownership enforcement so a user can only read/write their own rows (FR-033), scoped to the anonymous-UUID identity model resolved in §6.2.

## 5. Privacy & Safety Requirements

- **FR-043**: The Claude/Anthropic API key MUST live only in backend environment configuration (e.g., `admin-app/.env`, gitignored — mirroring how `SUPABASE_KEY` is already handled in this repo) and MUST NEVER be embedded in, or reachable from, the mobile app bundle.
- **FR-044**: Raw voice audio MUST NEVER be transmitted off-device or persisted anywhere — transcription happens on-device (§6.1); only the resulting transcript text is sent to the backend.
- **FR-045**: Uploaded images MUST be validated (type + size) before storage or transmission to the vision model.
- **FR-046**: Every private route (conversations, messages, saved content) MUST check the requester owns the resource before returning or mutating it.
- **FR-047**: Request bodies MUST be size-limited and rate-limited to prevent abuse of the (paid, third-party) Claude API — see §6, since no rate limiting exists anywhere in the current backend today.

## 6. Resolved Decisions *(previously "Clarifications Needed" — resolved for v1; revisit if wrong)*

Each item below was a genuine open question the stakeholder's prompt left unresolved. Resolved here with the option that best fits the existing system (§0) — i.e., reusing what already exists over introducing new infrastructure — so the feature ships without silently expanding scope. Flagged as **v1 decision** because a couple of these (2, 6) trade off a real limitation for staying in-scope; they're revisitable later as separate, explicitly-scoped work.

1. **Speech-to-text provider → none; on-device transcription, Claude-only stack.**
   **Updated per stakeholder: no OpenAI, no second AI vendor — Claude only.** Anthropic's API has no audio/speech-to-text endpoint, so "use Claude for STT too" isn't literally available — the resolution that actually satisfies "Claude only" is to remove cloud STT entirely and transcribe **on-device**, using the phone's native speech recognizer (Android `SpeechRecognizer` / iOS `Speech` framework, via the Flutter `speech_to_text` package). Consequences, all positive: zero new AI/cloud vendor, no `OPENAI_API_KEY`, no backend `speechToTextService`, no audio upload or server-side temp-file handling at all — raw audio never leaves the device, which also makes FR-008/FR-044 (delete temp audio after use) trivially true rather than something to implement. Only the resulting transcript text is ever sent to the backend, exactly like typed text. Tradeoff, stated plainly: on-device recognizer quality/language coverage varies by device OS/version and is weaker on Tamil/Thanglish than a top-tier cloud model would be — accepted in exchange for staying single-vendor; revisit only if real-device testing shows it's unusably poor.

2. **User identity → reuse the existing anonymous per-device UUID.**
   Rationale: every other data-bearing module in this app (Podcast progress, E-book bookmarks/library) already uses this exact mechanism, and there is no real login system to hook into (§0). Introducing real auth is a separate, much larger initiative that would touch `SessionManager`, the login/signup screens, and every existing module — explicitly out of scope per "do not modify unrelated... existing functionality." **Accepted limitation**: a user's AI chat history and saved content do not survive an app reinstall or follow them to a new device, exactly like their podcast progress and E-book library don't today. This is consistent with existing product behavior, not a regression.

3. **Rate limit & usage limit numbers:**
   - **30 AI generations per user per rolling 24h** (text/voice/image generations combined — this is the number that gates the paid Claude calls; on-device transcription itself is free and uncapped).
   - **10 requests per minute per user** (burst guard, independent of the daily cap).
   - **Max recording length: 3 minutes** per voice note (UX/simplicity cap, not a cost constraint now — well above what a single content request needs).
   - **Max image upload: 8MB raw, client-compressed to ≤2MB / longest edge ≤1600px before upload** (keeps well under Claude's vision input limits with margin).
   These are deliberately conservative defaults sized for a community app, not enterprise traffic; sized to be raised via config, not code change, if usage patterns show they're too tight.

4. **Backend host & protection scope → `admin-app`, but only the new `/api/ai/**` routes get new middleware.**
   `admin-app` is the only backend in the repo (§0) and has zero auth/rate-limiting on *any* existing route today. Retrofitting auth onto the entire existing surface (habits, buttons_config, community/podcast/ebook CRUD) is unrelated, unscoped work the stakeholder didn't ask for and that risks breaking the mobile app's existing plain-HTTP calls to those endpoints. **Decision**: a new, self-contained `aiUsageGuard` middleware (identity + rate-limit + daily-usage-limit, keyed off the anonymous `user_id` carried in each AI request) applies *only* to the new AI router. It is in-process/in-memory (no Redis in this stack today); documented as a known scaling limit if `admin-app` is ever run as more than one instance.

5. **Image/voice retention:**
   - **Voice**: raw audio never leaves the device (on-device transcription per §6.1 update) — there is no server-side audio artifact to retain or delete. Only the transcript text is stored, as `ai_messages.message`.
   - **Images**: persisted indefinitely in Supabase Storage (same precedent as podcast covers / e-book covers, which also persist indefinitely with no existing TTL mechanism in this codebase), under `ai-content/{user_id}/{conversation_id}/{message_id}.{ext}`. Deleted only as a cascade when the owning conversation is deleted by the user.

6. **Claude model & streaming → non-streaming v1, backend-configurable model.**
   Rationale: the mobile app has no existing WebSocket/SSE plumbing (every existing backend call, e.g. `/api/habits`, is a plain REST round-trip), so real token-streaming is a genuine new capability, not a reuse of something that exists. **v1 decision**: single request/response call to the Claude Messages API per turn; "Stop generation" is implemented as the client aborting the in-flight HTTP request, which satisfies the user-facing need ("let me stop waiting") without new server infrastructure. The model id is env-configurable (`CLAUDE_MODEL`, defaulting to the current Sonnet vision-capable model) so it can be upgraded without a code change. True incremental streaming is a clearly separable fast-follow if response latency proves to be a problem in testing.

## 7. Testing Checklist *(from stakeholder's §18, retained verbatim as acceptance testing scope)*

1. Send a text request
2. Send a Thanglish request
3. Send a Tamil request
4. Send an English request
5. Record voice and convert it to text
6. Cancel voice recording
7. Deny microphone permission
8. Upload an image
9. Remove an uploaded image
10. Send text with an image
11. Generate funny content
12. Generate professional content
13. Generate friendly content
14. Copy the AI response
15. Share the AI response
16. Save the AI response
17. Regenerate the response
18. Continue an old conversation
19. Delete a conversation
20. Handle no internet connection
21. Handle Claude API failure
22. Handle empty input
23. Handle duplicate button taps
24. Verify dark mode
25. Verify light mode
26. Verify different mobile screen sizes

## 8. Review & Acceptance Checklist

**Content quality**
- [x] No implementation stack mandated in this document beyond what's a genuine product requirement (Claude specifically is a product decision, not an implementation detail, since the feature *is* "a Claude-powered assistant")
- [x] Written in terms testable by someone without reading the code
- [x] All mandatory sections present

**Requirement completeness**
- [x] All `[NEEDS CLARIFICATION]` markers resolved — see §6 Resolved Decisions
- [x] Requirements are individually testable (FR-001…FR-047)
- [x] Success criteria are observable (acceptance scenarios in §2.1)
- [x] Scope explicitly bounded (FR-041, FR-042; §0 constraints)
- [x] Dependencies on existing system called out (§0)

## 9. Execution Status

- [x] Input prompt parsed and restructured
- [x] Existing repo/backend inspected for grounding (§0)
- [x] User scenarios drafted
- [x] Functional requirements generated and numbered
- [x] Key entities identified
- [x] Clarifications resolved (§6) — decisions made to fit existing system rather than expand scope; flagged as revisitable, not stakeholder-confirmed line-by-line
- [x] `plan.md` — see `specs/001-ai-content-assistant/plan.md`
- [ ] `tasks.md` (implementation task breakdown) — not started, blocked on `plan.md` review

---

*Status: `plan.md` now exists alongside this spec. No application code has been changed as part of producing either document.*
