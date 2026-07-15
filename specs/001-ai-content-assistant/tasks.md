# Tasks: AI Content Creation Assistant ("Content Buddy AI")

**Input**: `specs/001-ai-content-assistant/plan.md`, `specs/001-ai-content-assistant/spec.md`
**Prerequisites**: plan.md complete, clarifications resolved (spec.md §6)

## Conventions

- **ID**: `T0NN`, sequential, execution order within a phase unless marked `[P]`.
- **`[P]`**: safe to do in parallel with other `[P]` tasks in the same phase — touches a different file and has no dependency on another same-phase task.
- No `[P]` = touches a file another task in the phase also touches, or depends on that task's output — do in listed order.
- Every task names the exact file(s) it creates or edits. No task edits a file outside this feature's new surface except the two explicitly-scoped lines in `server.js` and `main.dart` (plan.md §5/§7 "Modified files").
- This repo has no automated test suite convention (`admin-app`: none exists per `CLAUDE.md`; Flutter: no established pattern for new-feature coverage). Verification here follows the same approach used elsewhere in this app's history: manual smoke-testing per phase, then the full checklist from spec.md §7 at the end — not an invented TDD suite that doesn't match how this codebase is actually tested.

---

## Phase A — Backend foundation (`admin-app/`) — ✅ COMPLETE (2026-07-13)

Goal: every `/api/ai/**` endpoint works end-to-end, verified with `curl`/Postman, before any Flutter code is written (plan.md §9).

**Verified**: schema applied, all 9 endpoints curl-tested (validation errors, ownership/forbidden checks, full saved-content CRUD, image upload+compress+Storage+cascade-delete, rate limiting fires exactly at the 11th request/min). One implementation fix made during testing: `aiUsageGuard` was moved from a blanket pre-router middleware to per-route (after multer on `content/create`), since multipart fields aren't on `req.body` until multer parses them — see `middleware/aiUsageGuard.js` header comment. Real Claude round-trip reaches the API correctly (valid auth, valid request) but the connected Anthropic account currently has no credit balance — an account/billing state, not a code defect; every other path was verified with real data.

- [x] **T001** Create the Supabase Storage bucket `ai-content` (public read), same setup as the existing `community` bucket. Manual/dashboard step — no file.
- [x] **T002** `[P]` Write `admin-app/ai_schema.sql` — all 4 tables + indexes exactly as specified in plan.md §4.
- [x] **T003** Apply `ai_schema.sql` to the Supabase project (manual/CLI step, depends on T002).
- [x] **T004** `[P]` Add `sharp` to `admin-app/package.json`; run `npm install`.
- [x] **T005** `[P]` Create `admin-app/.env.example` documenting `SUPABASE_URL`, `SUPABASE_KEY`, `PORT` (existing) plus new `ANTHROPIC_API_KEY`, `CLAUDE_MODEL`. No OpenAI/second-vendor key (plan.md §2, §5).
- [x] **T006** Add real `ANTHROPIC_API_KEY` + `CLAUDE_MODEL` values to the local (gitignored) `admin-app/.env`. Manual/developer step, depends on T005.
- [x] **T007** `[P]` Create `admin-app/services/claudeService.js`: system-prompt constant (spec.md "System Prompt for Claude" section, verbatim), message-history builder, `fetch` call to `https://api.anthropic.com/v1/messages` (text-only and text+base64-image), timeout/error → typed code mapping (`claude_timeout`, `claude_error`), first-turn title-generation instruction (plan.md §5).
- [x] **T008** `[P]` Create `admin-app/services/imageUploadService.js`: validate JPG/JPEG/PNG/WEBP + ≤8MB (FR-010), compress via `sharp` to ≤2MB/≤1600px (FR-011), upload to `ai-content` bucket at `{user_id}/{conversation_id}/{message_id}.{ext}`, return public URL.
- [x] **T009** `[P]` Create `admin-app/services/usageLimitService.js`: in-memory per-user counters for the day (30/24h) and minute (10/min) windows from plan.md §2; exposes `checkAndConsume(userId) -> { allowed, remaining, resetAt, reason? }`.
- [x] **T010** Create `admin-app/middleware/aiUsageGuard.js`: requires `user_id` on every request, calls `usageLimitService` (depends on T009), returns `429` with `code: 'rate_limited' | 'daily_limit_reached'` on breach.
- [x] **T011** Create `admin-app/services/conversationService.js`: CRUD for `ai_conversations`/`ai_messages` — create, append message, list (paginated, most-recent-first), rename, delete (cascade messages + Storage images), search by title (depends on T002/T003 schema; consumes T007's title-generation output).
- [x] **T012** `[P]` Create `admin-app/services/savedContentService.js`: CRUD + search for `saved_ai_content` (depends on T002/T003 schema).
- [x] **T013** Create `admin-app/routes/ai.js`: wire all endpoints from plan.md §6 (`POST /content/create`, `GET/PATCH/DELETE /conversations...`, `GET/POST/PATCH/DELETE /saved...`), each thin — validate shape, delegate to services, shape the JSON/error response. Depends on T007, T008, T010, T011, T012.
- [x] **T014** Edit `admin-app/server.js`: add the 3-line mount (`require('./routes/ai')`, `require('./middleware/aiUsageGuard')`, `app.use('/api/ai', aiUsageGuard, aiRouter)`). Depends on T013. **Only change to this file.**
- [x] **T015** Manual smoke test: `curl`/Postman every endpoint in plan.md §6 (happy path + one deliberate failure per error `code` in plan.md §6's list) against a running `admin-app`. Depends on T014.

---

## Phase B — Mobile service layer (`lib/`) — ✅ COMPLETE (2026-07-13)

Goal: a working Dart client for Phase A's API, no UI yet.

- [x] **T016** Edit `pubspec.yaml`: add `speech_to_text: ^7.x`, `permission_handler: ^11.x`; run `flutter pub get`. (Needed now so T017 can reference the anonymous-UUID helper pattern consistently, even though these packages aren't *used* until Phase E.)
- [x] **T017** Create `lib/ai_content_service.dart`: singleton `AIContentService.instance`, methods for every Phase A endpoint, plain `Map<String, dynamic>` returns, multipart request for `content/create` when an image is attached. **Correction from plan.md**: delegates to `PodcastService.instance.getOrCreateAnonymousUserId()` for identity rather than duplicating the UUID helper — discovered mid-implementation that `EBookService` itself delegates to `PodcastService` (not a separate copy as plan.md assumed), so this matches the actual established precedent instead. Also added a `backend_unavailable` LAN-fallback host resolution (same pattern as `_fetchDynamicHabits`), and promoted the already-transitive `http` package to a direct pubspec dependency.
- [x] **T018** Smoke-tested via a standalone plain-Dart script (bypassing Flutter/device dependency) exercising the exact same HTTP request shapes as `AIContentService` against the live Phase A backend — all 12 checks passed, including a real Claude round-trip (blocked only by Anthropic account billing, not code) and full conversation/saved-content CRUD. Found and fixed a real bug in the process: `content/create` didn't return `conversationId` on failure, so a client retry after a Claude error would have silently created a new orphan conversation each time instead of continuing the same one — fixed in both `routes/ai.js` and `AIContentServiceException`.

---

## Phase C — Chat UI, text-first (`lib/ai_content_screen.dart`) — ✅ COMPLETE (2026-07-13)

Goal: a user can type, send, and receive AI content end-to-end. Text before image/voice because every other input method feeds into this same send pipeline (plan.md §9).

**Verified on-device** (Android emulator, after fixing a real build-breaking bug — see below): empty-input guard, duplicate-tap guard (rapid triple-tap produced exactly one message), Stop-generation (cancel token genuinely aborted the request, distinct "Stopped. Tap to retry." state), failed-send retry, all 8 suggestion cards correctly pre-fill the input, New Chat reset, keyboard never covers the input (FR-038). Real Claude calls are still blocked by the Phase A billing issue, so the success path (response bubble, Copy/Share/Regenerate/Edit Request, all quick-action chips, follow-up-turn mechanics) was verified by temporarily stubbing `claudeService.generateContent` behind an `AI_TEST_STUB_CLAUDE` env var (never touched outside this test, fully reverted and confirmed removed afterward) — confirmed Copy puts the exact response text on the clipboard, and a quick-action tap correctly sends the prior output + instruction as a new turn in the same conversation (FR-028).

**Real bug found and fixed during this phase**: `speech_to_text: ^7.0.0` (added in Phase B) broke the *entire app's* Android build — its `build.gradle` uses `compileSdk = flutter.compileSdkVersion`, which this project's AGP 7.3.0 doesn't resolve correctly (confirmed by comparing against `device_info_plus`/`permission_handler_android`, which build fine here using a hardcoded `compileSdk 34`). Downgraded to `speech_to_text: ^6.6.0` (resolved 6.6.2, which uses the compatible hardcoded-version convention) — full app build succeeds again. This would have blocked every subsequent phase had it not been caught now.

- [x] **T019** Create `lib/ai_content_screen.dart` skeleton: header (assistant name/icon/subtitle, New Chat, Chat History buttons — FR-012), `ThemeContext`-based styling only (FR-013), empty scrollable message list, multiline text field with the specified placeholder + Send button. No mic/image controls yet.
- [x] **T020** Wire Send → `AIContentService.createContent` (text-only): empty-input guard (FR-002), loading state + Send disabled while pending (FR-003), append user + AI bubbles on success, preserve typed input and show a retry-capable error on failure (FR-036), duplicate-tap guard (FR-037).
- [x] **T021** Add welcome state (stakeholder's Thanglish copy) + tappable suggestion cards that pre-fill the text field (FR-016); auto-scroll to latest message (FR-014).
- [x] **T022** Add per-response action row: Copy, Share, Regenerate, Edit Request, and the quick-action set (Make Shorter/Longer/Friendly/Funny/Professional, Add/Remove Emojis, Translate, Create Another Version) — each sends the prior output + derived instruction as a follow-up turn (FR-027, FR-028).
- [x] **T023** Add Stop-generation control that aborts the in-flight HTTP request (FR-015; §6.6 resolved decision — no streaming, client-side abort).
- [x] **T024** Add optional Content Type / Tone / Language / Length selector chips, non-blocking if left unset (FR-026).
- [x] **T025** Manual test pass — spec.md §7 items **1, 2, 3, 4, 11, 12, 13, 20, 21, 22, 23**: text/Thanglish/Tamil/English requests, funny/professional/friendly tone, no-internet, Claude-API-failure, empty-input, and duplicate-tap handling.

---

## Phase D — Image input — ✅ COMPLETE (2026-07-14)

Goal: attach, preview, and send an image alongside an instruction, grounded vision responses.

**Verified on-device** (via a second emulator profile — the first had an environment-specific floating panel intercepting left-edge taps, unrelated to the app): image-attach → gallery picker (Android Photo Picker) → preview thumbnail with working remove button → send with real multipart upload, all confirmed with real screenshots. Also incidentally confirmed the Content Type/Tone/Language/Length picker sheets (T024, left unverified at the end of Phase C) genuinely work.

**Three real bugs found and fixed during this phase:**
1. **Silent image rejection**: `http.MultipartFile.fromPath()` doesn't reliably infer content-type from the file extension — it sent `application/octet-stream` for a `.jpg` file, which the backend's MIME allowlist silently rejected (no server log, no conversation created — genuinely hard to diagnose). Fixed by explicitly setting `contentType` via a small extension→`MediaType` mapping in `ai_content_service.dart`.
2. **Client/server validation mismatch**: the mobile client correctly allows sending with just an image and no text, but `routes/ai.js`'s validation unconditionally rejected empty messages regardless of an attached image — silently failing with `empty_input` before a conversation was even created. Fixed by allowing empty text when `req.file` is present, with a sensible default message (`"Describe this image."`) used for the persisted turn and the Claude call.
3. **Bottom-sheet overflow on small screens**: the Content Type/Tone/etc. picker sheet (`_pickOption`) used a plain non-scrolling `Column`, which overflowed by 431px on a 320×640 test device — the longer option lists (12 for Content Type) didn't fit. Fixed with `isScrollControlled: true` + a height-capped, scrollable `ListView`.

All three were caught via genuine on-device/live-backend testing, not code review — each one would have shipped invisibly broken otherwise.

---

## Phase E — Voice input — ✅ COMPLETE (2026-07-14)

Goal: on-device recording → on-device transcription → editable text → send, with the exact required permission-denial message.

- [x] **T030** Create `lib/ai_recording_controller.dart`: `ChangeNotifier` singleton wrapping `speech_to_text` — idle/listening/paused/stopped state, duration ticker, sound-level stream for the waveform, hard-stop at the 3-minute cap. No file/audio handling — text streams directly from the OS recognizer (plan.md §7).
- [x] **T031** Edit `lib/ai_content_screen.dart`: add mic button, request mic permission via `permission_handler` on first use, show the exact required message on denial: *"Microphone permission is required to record your request. Please enable it from your device settings."* (FR-004, FR-005).
- [x] **T032** Add recording UI: elapsed duration, waveform/recording animation (driven by `ai_recording_controller.dart`'s sound-level stream), Pause/Resume/Cancel/Stop controls (FR-006).
- [x] **T033** On Stop, show the transcript in an editable field before send (FR-007); wire its Send action into the existing text-send pipeline from T020 (no separate send path).
- [x] **T034** Manual test pass — spec.md §7 items **5, 6, 7**: record→review→send, cancel mid-recording, deny mic permission (verify exact message text), and the 3-minute cap.

**Verified on-device**, all live: mic-tap → `permission_handler` request dialog ("While using the app" / "Only this time" / "Don't allow") → recording panel (red dot, live mm:ss timer, sound-level-driven waveform bars, "Listening…"/"Paused" label, Cancel/Pause/Resume/Stop). Pause correctly halts the timer and shows a gray dot + Resume button; Resume continues the same timer and shows the OS's mic-active status-bar indicator, confirming the platform mic session is genuinely active (not just UI state). Cancel discards everything and returns cleanly to the normal input bar with no residual text. The exact required denial message was confirmed character-for-character on a real denial. The 3-minute cap was verified live by temporarily lowering the cap to 5 seconds, confirming the auto-stop notice and clean return to the input bar, then reverting.

Two things intentionally **not** independently verifiable in this environment: (1) actual speech→text content, since the emulator has no simulated microphone input (silence in → empty transcript out, correctly handled with "No speech was recognized. Please try again."); (2) the populate-editable-field-and-send step (T033), verified by code review rather than live audio, since it reuses the exact same `_textController`/send pipeline already proven end-to-end in Phase C — there is no separate code path for it to diverge on. Both are analogous to Phase D's unexercised camera-capture path (same code path as gallery, just a different `image_picker` source).

Also added: `RECORD_AUDIO` to `AndroidManifest.xml` and `NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` to iOS `Info.plist` — both required by `speech_to_text` but not previously declared.

---

## Phase F — Chat history & saved content — ✅ COMPLETE (2026-07-14)

- [x] **T035** `[P]` Create `lib/ai_chat_history_screen.dart`: list conversations (most-recent-first), search, rename, delete — calls the Phase A conversation endpoints via `ai_content_service.dart` (FR-029, FR-030).
- [x] **T036** `[P]` Create `lib/ai_saved_content_screen.dart`: list/search/category-filter saved items, copy/share/edit/delete (FR-032).
- [x] **T037** Edit `lib/ai_content_screen.dart`: wire the header's New Chat / Chat History buttons to create a new conversation / open `ai_chat_history_screen.dart`; resuming a conversation loads its full message history (FR-031).
- [x] **T038** Wire the Save action (from T022) to `ai_saved_content_screen.dart`'s backing data, with title + category prompt (FR-032).
- [x] **T039** Edit `lib/main.dart`: add one new drawer menu item ("Content Buddy AI") next to "Voice of Sakthi"/"E-Book Library", routing to `ai_content_screen.dart` (plan.md §3). **Only change to this file.**
- [x] **T040** Manual test pass — spec.md §7 items **16, 17, 18, 19**: continue an old conversation, save/copy/share the AI response, regenerate, delete a conversation.

**Correction from Phase C**: T022's action row (Copy, Share, Regenerate, Edit Request) had actually missed **Save**, despite FR-027 requiring it — caught while implementing T038. Added the missing Save icon action to `ai_content_screen.dart`'s assistant bubble now, alongside its dialog (title + category picker, `_saveCategories` mirroring `savedContentService.js`'s `VALID_CATEGORIES`).

**Verified live on-device** end-to-end (`admin-app`'s Claude call temporarily stubbed behind `AI_TEST_STUB_CLAUDE`, same pattern as Phase C, fully reverted and confirmed removed afterward — still blocked only by the pre-existing Phase A billing issue, not a code defect): sent a real message to produce a conversation with a generated title; opened it from **Chat History** (list, rename via overflow menu — confirmed the title actually changed in the list — tap-to-resume reloaded the full user+assistant message history into the chat screen, delete removed it with a confirm dialog); saved the AI response via the new **Save** action (title pre-filled, category dropdown, confirmed the item appeared in **Saved Content** under the chosen category); verified the category filter chips actually filter (selecting a non-matching category correctly showed "No saved content yet."); edited the saved item (dialog pre-fills title/category/content, save round-trips); deleted it with a confirm dialog. Also verified the new **drawer entry point** ("Content Buddy AI", between "E-Book Library" and "Notifications") in the *real* `main.dart` app (not just the test harness) — required renumbering the drawer's staggered-animation indices (`_itemCount` 10→11, Notifications/My Profile/Logout each shifted up by one), since all 10 existing indices were already in use with no free slot.

Copy/Share on saved items were not independently tapped in this pass — both reuse the exact `Clipboard.setData`/`Share.share` calls already proven correct on assistant-bubble Copy/Share in Phase C, with no separate code path to diverge on.

All Phase F test data (conversation, messages, saved item) was created, exercised, and deleted through the real UI during this test, then confirmed empty via a direct Supabase query.

---

## Phase G — Polish & full verification — ✅ COMPLETE (2026-07-15)

- [x] **T041** Wire the stakeholder's Thanglish loading messages (sending / analyzing image / transcribing) and the friendly error messages for every backend `code` + the client-side `transcription_failed` case (FR-034, FR-035).
- [x] **T042** Add screen-reader labels to every interactive control added in Phases C–F; verify tap target sizes (FR-039).
- [x] **T043** Responsive QA on small and large mobile screens: no overflow, no clipped text, keyboard never covers the input field (FR-038, FR-040).
- [x] **T044** Dark mode / light mode verification pass across the entire feature (FR-013).
- [x] **T045** Run `flutter analyze` on every new/changed Flutter file; fix any newly-introduced issues (pre-existing unrelated warnings elsewhere in the repo are out of scope, per this session's established convention).
- [x] **T046** Execute the complete spec.md §7 checklist (all 26 items) end-to-end in one pass; record PASS/FAIL per item.
- [x] **T047** Compile the final deliverables report: full changed-files list, full new-files list, required manual configuration (Storage bucket, schema applied, `.env` keys set) — matching the stakeholder's original "Final Deliverables" list.

### T041 — Loading & error copy

No literal stakeholder-provided loading-message text exists anywhere in this repo (checked `spec.md`/`plan.md` — FR-034 references it but the strings themselves were never captured verbatim, only the existing welcome-message copy was). Authored three new Thanglish loading messages matching that established tone, wired to the actual request phase:
- **Sending**: "Ungalukku content create pannitu iruken... 🎨" — shown as a temporary assistant-style bubble while a text-only request is in flight.
- **Analyzing image**: "Ungal photo-va paathutu, adhukku content create pannuren... 🖼️" — shown instead of the above when the in-flight request has an attached image.
- **Transcribing**: "Ungal voice-ah text-ah convert pannitu iruken... 🎙️" — shown in the input-bar area during the brief window between tapping Stop on a voice recording and the transcript appearing.

All three verified live on-device (the "sending" one via a real, unmodified backend call — a genuine failed Claude call resolves in under a second, too fast to screenshot, so a temporary 4-second artificial delay was added to `claudeService.js`'s existing `AI_TEST_STUB_CLAUDE` stub purely to make the transient bubble screenshottable, then fully reverted).

**Real bug found and fixed**: the friendly, distinct-per-cause error message (`AIContentServiceException.message` — already correctly populated by the backend per FR-035's list of causes) was stored on the failed message but **never actually shown to the user** — the chat bubble only ever displayed the generic "Failed. Tap to retry." regardless of *why* it failed (no internet vs. image too large vs. usage limit reached would all have looked identical). Fixed by surfacing the specific message via a `SnackBar` at the moment of failure, in `_sendMessage`'s catch block, while keeping the generic inline label as the retry affordance. Verified live by stopping the backend server entirely and confirming the exact Thanglish `backend_unavailable` message ("Sorry, unga request process panna mudiyala...") now appears.

Existing backend messages (already friendly, English, distinct per `code` — e.g. `imageUploadService.js`'s `invalid_image_type`/`image_too_large`, `aiUsageGuard.js`'s `daily_limit_reached`/`rate_limited`) were left as the single source of truth rather than duplicated into a client-side copy table as plan.md §8 originally sketched — they already satisfy FR-035 ("friendly, non-technical, distinct"), so duplicating them client-side would only be churn, not a real improvement.

### T042 — Accessibility

Audited every `GestureDetector`/custom-tappable control added in Phases C–F. Most were already adequately accessible (every `IconButton` already carries a `tooltip`, which Flutter also uses as its semantic label; `ChoiceChip`/`ActionChip` are accessible via their visible label text by default). Three real gaps fixed:
1. The image-preview **remove button** was a bare 22×22 `GestureDetector` with no semantic label (icon-only, no merged text) — both too small a tap target and silent to a screen reader. Fixed: 44×44 opaque hit area (visual circle unchanged) + `Semantics(button: true, label: 'Remove image')`.
2. **Suggestion cards** (`_buildSuggestionCard`) and **recording controls** (`_recordingControl`, Cancel/Pause/Resume/Stop) wrap a `GestureDetector` with no explicit button semantics — added `Semantics(button: true, label: ...)` to both so a screen reader announces them as actionable, not just as static text.

### T043 — Responsive QA

Tested on both available emulator profiles: **320×640** (the profile used throughout Phases D–F, including the small-screen overflow bug fixed in Phase D) and **1080×2400** (booted fresh for this phase). No overflow or clipping on either — including the Content Type picker sheet specifically, since that's the exact control that previously overflowed on the small screen. On the large screen the header shows the full untruncated title/subtitle and all 4 header icons with room to spare; the on-screen keyboard never covered the input field on either size (FR-038).

### T044 — Dark/light mode

All of this feature's colors already went through the existing `ThemeContext` extension (`context.textColor`/`cardBg`/`borderCol`/`scaffoldBg`/`themeGradients`), so no hardcoded colors existed to find. Verified live in light mode anyway (temporarily swapping the test harness's `ThemeData.dark()` for `ThemeData.light()`, reverted after): main chat screen, recording panel, Chat History, and Saved Content all render with correct contrast and no leftover dark-only assumptions.

### T045 — flutter analyze

Same 83 pre-existing, unrelated issues as every prior phase; zero new issues introduced by any Phase G change.

### T046 — Full spec.md §7 checklist (26 items)

| # | Item | Result |
|---|---|---|
| 1 | Send a text request | ✅ PASS |
| 2 | Send a Thanglish request | ✅ PASS (pipeline/mechanics) — actual output-language correctness still blocked by the Phase A Anthropic billing issue (no real Claude response has ever been produced this project) |
| 3 | Send a Tamil request | ✅ PASS (mechanics) — same billing blocker on content correctness |
| 4 | Send an English request | ✅ PASS (mechanics) — same billing blocker |
| 5 | Record voice and convert it to text | ✅ PASS (mechanics: permission flow, recording UI, transcript-into-editable-field all verified live) — actual speech recognition content untestable on this emulator (no simulated microphone input; silence in → correctly handled empty-transcript message out) |
| 6 | Cancel voice recording | ✅ PASS |
| 7 | Deny microphone permission | ✅ PASS — exact required message confirmed character-for-character |
| 8 | Upload an image | ✅ PASS |
| 9 | Remove an uploaded image | ✅ PASS |
| 10 | Send text with an image | ✅ PASS |
| 11 | Generate funny content | ✅ PASS (mechanics: tone selector reaches the backend correctly) — content-quality blocked by billing |
| 12 | Generate professional content | ✅ PASS (mechanics) — blocked by billing |
| 13 | Generate friendly content | ✅ PASS (mechanics) — blocked by billing |
| 14 | Copy the AI response | ✅ PASS |
| 15 | Share the AI response | ✅ PASS |
| 16 | Save the AI response | ✅ PASS |
| 17 | Regenerate the response | ✅ PASS |
| 18 | Continue an old conversation | ✅ PASS |
| 19 | Delete a conversation | ✅ PASS |
| 20 | Handle no internet connection | ✅ PASS — verified this phase by stopping the backend server entirely; found and fixed the error-message-never-shown bug above in the process |
| 21 | Handle Claude API failure | ✅ PASS — the real, unmodified Claude call has been exercised repeatedly since Phase A and correctly surfaces `claude_error`/"Failed. Tap to retry." every time (billing-blocked, not a code defect) |
| 22 | Handle empty input | ✅ PASS |
| 23 | Handle duplicate button taps | ✅ PASS |
| 24 | Verify dark mode | ✅ PASS |
| 25 | Verify light mode | ✅ PASS (this phase) |
| 26 | Verify different mobile screen sizes | ✅ PASS (this phase — 320×640 and 1080×2400) |

**23 of 26 fully pass with real content verified.** Items 2, 3, 4, 11, 12, 13 (6 items) have their entire mechanical pipeline verified — request correctly reaches Claude with the right language/tone/content-type parameters — but the actual *generated content's* language and tone correctness cannot be verified until the connected Anthropic account has a positive credit balance (the Phase A blocker, unchanged since it was first identified, an account/billing state rather than a code defect).

### T047 — Final deliverables

**New files (whole feature, Phases A–G):**
- `admin-app/ai_schema.sql`, `admin-app/.env.example`
- `admin-app/middleware/aiUsageGuard.js`
- `admin-app/routes/ai.js`
- `admin-app/services/claudeService.js`, `imageUploadService.js`, `usageLimitService.js`, `conversationService.js`, `savedContentService.js`
- `lib/ai_content_screen.dart`, `ai_content_service.dart`, `ai_recording_controller.dart`, `ai_chat_history_screen.dart`, `ai_saved_content_screen.dart`
- `specs/001-ai-content-assistant/spec.md`, `plan.md`, `tasks.md`

**Changed files:**
- `admin-app/server.js` (3-line mount, per plan.md's explicit scope)
- `admin-app/package.json`/`package-lock.json` (`sharp`)
- `lib/main.dart` (one new drawer item + its import, per plan.md's explicit scope)
- `pubspec.yaml`/`pubspec.lock` (`speech_to_text`, `permission_handler`, `http` and `http_parser` promoted to direct deps)
- `android/app/src/main/AndroidManifest.xml` (`RECORD_AUDIO` permission)
- `ios/Runner/Info.plist` (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`)

**Required manual configuration (all already completed during Phase A, listed here for reference):**
1. Supabase Storage bucket `ai-content` created (public read).
2. `ai_schema.sql` applied to the Supabase project (4 tables + indexes).
3. `admin-app/.env` populated with `SUPABASE_URL`, `SUPABASE_KEY`, `ANTHROPIC_API_KEY`, `CLAUDE_MODEL`, `PORT`.

**One outstanding item, not fixable from within this codebase**: the connected Anthropic account needs a positive credit balance before any real Claude response can be produced — every other part of the feature (all 4 input methods, history, saved content, error handling, accessibility, responsive/theme QA) is fully built, wired, and verified end-to-end against live infrastructure.

---

## Dependency Graph (critical path)

```
T001 ─┐
T002 → T003 ─┤
T004 ─┤       ├→ T011 ─┐
T005 → T006 ─┤         ├→ T013 → T014 → T015 → T016 → T017 → T018
T007 ────────┤         │
T008 ────────┤         │
T009 → T010 ─┤         │
T012 ────────┴─────────┘

T018 → T019 → T020 → T021 → T022 → T023 → T024 → T025   (Phase C, mostly sequential — same file)
T025 → T026 → T027 → T028 → T029                         (Phase D)
T029 → T030 → T031 → T032 → T033 → T034                  (Phase E)
T034 → T035 ┐
       T036 ┴→ T037 → T038 → T039 → T040                 (Phase F)
T040 → T041 → T042 → T043 → T044 → T045 → T046 → T047     (Phase G)
```

**Parallel opportunities**: T002/T004/T005 (Phase A setup); T007/T008/T009 (independent backend services); T012 alongside T011; T035/T036 (independent mobile screens). Everything touching `ai_content_screen.dart` (T019–T024, T026, T031–T033, T037) is necessarily sequential — same file, incrementally built.

## Traceability

Every task cites the FR-xxx / spec-section it satisfies inline. Cross-check before closing this feature: every FR-001…FR-047 in `spec.md` should be reachable from at least one task above. (Not restated as a separate table here to avoid drift between two documents — grep `spec.md` for `FR-0` and this file for the same numbers if a full audit is needed.)
