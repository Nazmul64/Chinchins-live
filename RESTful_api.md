# 🚀 ChinChins Live — 100% Production-Grade RESTful API & System Architecture Specification

> **Base URL:** `https://chinchins.live/api` or `http://127.0.0.1:8000/api`  
> **WebSocket Gateway (Laravel Reverb):** `wss://chinchins.live/app`  
> **LiveKit Media Server:** `wss://chinchins.live/livekit`  
> **Default Request Headers:**
> ```http
> Accept: application/json
> Content-Type: application/json
> Authorization: Bearer <AUTH_TOKEN>
> ```
> *(Fallback Header: `X-User-Id: <USER_ID>` or query parameter `?user_id=<USER_ID>`)*

---

## 📑 Table of Contents
1. [Root Cause Analysis: Automatic Call Disconnect Resolution](#1-root-cause-analysis-automatic-call-disconnect-resolution)
2. [One-to-One Audio & Video Calling APIs](#2-one-to-one-audio--video-calling-apis)
3. [LiveKit Live Streaming & Guest Co-Host Lifecycle](#3-livekit-live-streaming--guest-co-host-lifecycle)
4. [Voice Chat & Party Rooms Architecture](#4-voice-chat--party-rooms-architecture)
5. [Real-Time Gift Engine & Profile Accumulation](#5-real-time-gift-engine--profile-accumulation)
6. [User Profile, Charm Level & Wallet APIs](#6-user-profile-charm-level--wallet-apis)
7. [WebSocket Reverb Channels & Event Catalog](#7-websocket-reverb-channels--event-catalog)

---

## 1. Root Cause Analysis: Automatic Call Disconnect Resolution

### 1.1 The Actual Root Causes Identified
1. **Ghost Timeout Cancellation Race Condition:**
   - When a call was initiated, Flutter started a 50-second timer (`_ringTimeoutTimer`).
   - If the receiver accepted the call at around 35–45 seconds, the call became active. However, if any delayed `call.cancelled` event was received over WebSocket or if a background signal arrived with `action: call_cancelled`, Flutter's `_wsCancelledSub` immediately executed `_terminateCallSession('Call was cancelled')` regardless of whether `_isCallAccepted` was `true`.
   - **Fix Implemented:** Added strict call state guards in `video_call_screen.dart` (`_wsCancelledSub`, `_startStatusPolling()`) to ignore cancellation events once the call is accepted (`_isCallAccepted == true`).

2. **Backend Cancel Request on Active Calls:**
   - If the caller phone experienced high network jitter and fired an uncancelled timeout cancel request (`/api/call/cancel`), the backend previously allowed cancelling calls without verifying if the call had already transitioned to `connected` or `accepted`.
   - **Fix Implemented:** In `CallController::cancel`, `WebRTCCallController::cancel`, and `LivePrivateCallApiController::cancel`, added an immutable guard:
     ```php
     if (in_array($call->status, ['connected', 'accepted', 'completed'])) {
         return response()->json([
             'status'  => true,
             'message' => 'Call already connected. Ring-timeout/cancel ignored so the live call is not cut.',
         ], 200);
     }
     ```

3. **Background Daemon Timeout Sync Discrepancy:**
   - The scheduled job `call:timeout-check` enforces a 45-second timeout on ringing calls. Previously, if `call_sessions` and `calls` tables had differing IDs, one record could remain without `answered_at`, triggering a false `missed` broadcast that terminated the healthy session.
   - **Fix Implemented:** Synchronized `answered_at` across both `calls` and `call_sessions` by `channel_name` and verified active connection status before issuing timeouts.

4. **Gift Accumulation in Receiver's Profile (Audio 1 Fix):**
   - In `LiveStreamApiController::sendGift` and `PartyRoomApiController::sendGift`, transactions were recorded in `gift_transactions` but `UserGift` records were never generated, leaving the receiver's profile empty.
   - In `InCallApiController::getReceivedGifts` (`/api/v1/user/received-gifts`), the backend was prioritizing auth user over the query parameter `user_id`. When User A visited User B's profile, it returned User A's data instead of User B's received gifts.
   - **Fix Implemented:** Synchronously write `UserGift` and `GiftTransaction` across all gift endpoints (`gifts/send`, `live/send-gift`, `party-rooms/{id}/send-gift`, `call/send-gift`), increment receiver `received_coins`, update charm level, and prioritize `user_id` query parameter in all profile/gift endpoints with full Flutter `UserGiftsData` compatibility.

---

## 2. One-to-One Audio & Video Calling APIs

### 2.1 Initiate Call
- **Endpoint:** `POST /api/call/initiate` or `POST /api/calls/initiate`
- **Request Body:**
```json
{
  "receiver_id": 2,
  "call_type": "video",
  "is_free_trial": false,
  "rate_per_minute": 100
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "success": true,
  "message": "Call initiated successfully.",
  "data": {
    "call_id": 105,
    "channel_name": "chinchins_call_105_1739281920",
    "caller_id": 1,
    "receiver_id": 2,
    "status": "ringing",
    "call_type": "video",
    "livekit_url": "wss://chinchins.live/livekit",
    "livekit_token": "eyJhbGciOi...",
    "caller_token": "eyJhbGciOi...",
    "dial_tone_url": "https://chinchins.live/sounds/dial_tone.mp3",
    "ringtone_url": "https://chinchins.live/sounds/incoming_ringtone.mp3"
  }
}
```

### 2.2 Confirm Ringing (Heartbeat from Receiver)
- **Endpoint:** `POST /api/call/ringing`
- **Request Body:**
```json
{
  "call_id": 105,
  "channel_name": "chinchins_call_105_1739281920"
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Ringing confirmed."
}
```

### 2.3 Accept Call (Explicit Receiver Action)
- **Endpoint:** `POST /api/call/accept` or `POST /api/calls/accept`
- **Request Body:**
```json
{
  "call_id": 105,
  "channel_name": "chinchins_call_105_1739281920"
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "success": true,
  "message": "Call accepted.",
  "data": {
    "call_id": 105,
    "channel_name": "chinchins_call_105_1739281920",
    "status": "connected",
    "livekit_url": "wss://chinchins.live/livekit",
    "receiver_token": "eyJhbGciOi...",
    "caller_token": "eyJhbGciOi...",
    "can_publish": true,
    "auto_publish": true,
    "start_video": true,
    "start_audio": true,
    "answered_at": "2026-10-11T12:00:00Z"
  }
}
```

### 2.4 Reject Call (Receiver Declined)
- **Endpoint:** `POST /api/call/reject`
- **Request Body:**
```json
{
  "call_id": 105,
  "reason": "busy"
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Call rejected successfully."
}
```

### 2.5 Cancel Call (Caller Cancelled Prior to Answer)
- **Endpoint:** `POST /api/call/cancel`
- **Request Body:**
```json
{
  "call_id": 105,
  "reason": "timeout_missed"
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Call cancelled successfully."
}
```

### 2.6 End Call (Terminate Active Session)
- **Endpoint:** `POST /api/call/end` or `POST /api/calls/end`
- **Request Body:**
```json
{
  "call_id": 105,
  "duration_seconds": 120
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Call ended successfully.",
  "data": {
    "call_id": 105,
    "duration_seconds": 120,
    "coins_spent": 200,
    "status": "ended"
  }
}
```

### 2.7 Get Call Status & Signals (Polling & Recovery)
- **Endpoint:** `GET /api/calls/{id}/status` or `GET /api/call/status?call_id={id}`
- **Response (200 OK):**
```json
{
  "status": true,
  "data": {
    "id": 105,
    "status": "connected",
    "caller_id": 1,
    "receiver_id": 2,
    "is_active": true,
    "is_ringing": false,
    "duration": 45
  }
}
```

---

## 3. LiveKit Live Streaming & Guest Co-Host Lifecycle

### 3.1 Start Live Stream (Host)
- **Endpoint:** `POST /api/v1/stream/start` or `POST /api/live/start`
- **Request Body:**
```json
{
  "title": "Evening Chill Session 🎵",
  "category": "music",
  "cover_image": "uploads/covers/stream_1.jpg",
  "resolution": "1080p",
  "fps": 30
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Live stream started successfully.",
  "data": {
    "stream_id": 42,
    "channel_name": "chinchins_live_42",
    "livekit_url": "wss://chinchins.live/livekit",
    "livekit_token": "eyJhbGciOi...",
    "can_publish": true,
    "adaptive_stream": true,
    "simulcast": true,
    "target_bitrate_kbps": 3000,
    "viewer_count": 0
  }
}
```

### 3.2 Join Live Stream (Viewer)
- **Endpoint:** `POST /api/v1/stream/join` or `POST /api/live/join`
- **Request Body:**
```json
{
  "stream_id": 42
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Joined live stream.",
  "data": {
    "stream_id": 42,
    "livekit_url": "wss://chinchins.live/livekit",
    "livekit_token": "eyJhbGciOi...",
    "can_publish": false,
    "host": {
      "id": 5,
      "name": "Aria Singer",
      "avatar_url": "https://chinchins.live/avatars/aria.png"
    },
    "viewer_count": 85
  }
}
```

### 3.3 Viewer Requests to Join as Guest / Co-Host
- **Endpoint:** `POST /api/v1/stream/request-join`
- **Request Body:**
```json
{
  "stream_id": 42
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Guest participation request submitted."
}
```

### 3.4 Host Accepts or Rejects Guest Request
- **Endpoint:** `POST /api/v1/stream/respond-request`
- **Request Body:**
```json
{
  "stream_id": 42,
  "request_id": 12,
  "action": "accept"
}
```
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "Request accepted. Guest authorized to publish tracks.",
  "data": {
    "guest_id": 10,
    "can_publish": true
  }
}
```

### 3.5 Kick Guest / Leave Guest Session
- **Endpoint:** `POST /api/v1/stream/kick-guest`
- **Request Body:**
```json
{
  "stream_id": 42,
  "guest_id": 10
}
```

### 3.6 End Live Stream (Host)
- **Endpoint:** `POST /api/v1/stream/end` or `POST /api/live/end`
- **Request Body:**
```json
{
  "stream_id": 42
}
```

---

## 4. Voice Chat & Party Rooms Architecture

### 4.1 Create Voice Chat Room
- **Endpoint:** `POST /api/party-rooms/create`
- **Request Body:**
```json
{
  "title": "Midnight Stories & Poetry",
  "room_type": "voice",
  "tag": "chill",
  "seat_count": 8
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 18,
    "room_id": "party_room_18",
    "channel_name": "party_room_18",
    "host_id": 1,
    "livekit_url": "wss://chinchins.live/livekit",
    "token": "eyJhbGciOi...",
    "seats": [
      { "seat_index": 0, "user_id": 1, "is_locked": false, "is_muted": false }
    ]
  }
}
```

### 4.2 Join Voice Room as Listener
- **Endpoint:** `POST /api/party-rooms/{id}/join`
- **Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "livekit_url": "wss://chinchins.live/livekit",
    "token": "eyJhbGciOi...",
    "can_publish": false
  }
}
```

### 4.3 Take or Request Seat
- **Endpoint:** `POST /api/party-rooms/{id}/take-seat`
- **Request Body:**
```json
{
  "seat_index": 2
}
```

### 4.4 Mute / Unmute Microphone on Seat
- **Endpoint:** `POST /api/party-rooms/{id}/toggle-mic`
- **Request Body:**
```json
{
  "is_muted": false
}
```

### 4.5 Leave Seat
- **Endpoint:** `POST /api/party-rooms/{id}/leave-seat`

### 4.6 Close Room
- **Endpoint:** `POST /api/party-rooms/{id}/end`

---

## 5. Real-Time Gift Engine & Profile Accumulation

### 5.1 Universal Send Gift API
- **Endpoint:** `POST /api/gifts/send` or `POST /api/gift/send` or `POST /api/live/send-gift`
- **Request Body:**
```json
{
  "receiver_id": 2,
  "gift_id": 5,
  "quantity": 1,
  "context": "live_stream",
  "stream_id": "stream_42"
}
```
- **Processing Guarantees:**
  - 1. Atomic decrement of coins from sender wallet.
  - 2. Atomic increment of coins and withdrawable earnings on receiver wallet.
  - 3. Immediate synchronous insert into `user_gifts` (Receiver profile showcase).
  - 4. Immediate synchronous insert into `gift_transactions`.
  - 5. Atomic increment of receiver's `received_coins`.
  - 6. Dynamic recalculation of receiver's Charm Level.
  - 7. Real-time Reverb broadcast of `LiveGiftSentEvent` with SVGA / PNG animation asset URLs.
- **Response (200 OK):**
```json
{
  "success": true,
  "status": true,
  "message": "Gift sent successfully!",
  "remaining_balance": 8000,
  "data": {
    "gift_id": 5,
    "gift_name": "Bengal Tiger",
    "total_coins": 2000,
    "icon_url": "https://chinchins.live/uploads/gifts/tiger.png",
    "animation_url": "https://chinchins.live/uploads/gifts/tiger.svga"
  }
}
```

### 5.2 Fetch User's Received Gifts (For Profile & Showcase)
- **Endpoint:** `GET /api/v1/user/received-gifts?user_id={id}` or `GET /api/gifts/received/{id}` or `GET /api/profile/{id}/gifts`
- **Response (200 OK):**
```json
{
  "status": true,
  "message": "User received gifts loaded successfully.",
  "total_received_coins": 12500,
  "data": {
    "user": {
      "id": 2,
      "account_id": "CC78921",
      "display_name": "Maya Model",
      "avatar_url": "https://chinchins.live/avatars/maya.jpg",
      "coins": 450,
      "received_coins": 12500
    },
    "charm_level": {
      "level": 2,
      "level_tag": "Lv.2",
      "progress": 25
    },
    "top_fan": {
      "id": 1,
      "name": "King David",
      "avatar_url": "https://chinchins.live/avatars/david.jpg",
      "fan_coins": 8000,
      "formatted": "8K",
      "crown": "gold"
    },
    "summary": {
      "total_unique_gifts": 4,
      "total_items_count": 12,
      "total_coins": 12500,
      "formatted_coins": "12.5K"
    },
    "profile_preview_gifts": [
      {
        "gift_id": 5,
        "name": "Bengal Tiger",
        "coins": 2000,
        "formatted_coins": "2K",
        "quantity": 3,
        "count_label": "x3",
        "total_coins": 6000,
        "image_url": "https://chinchins.live/uploads/gifts/tiger.png"
      }
    ],
    "gifts_received": [
      {
        "gift_id": 5,
        "name": "Bengal Tiger",
        "coins": 2000,
        "formatted_coins": "2K",
        "quantity": 3,
        "count_label": "x3",
        "total_coins": 6000,
        "image_url": "https://chinchins.live/uploads/gifts/tiger.png",
        "animation_url": "https://chinchins.live/uploads/gifts/tiger.svga"
      }
    ]
  }
}
```

### 5.3 Fetch In-App Gifts Store Catalog
- **Endpoint:** `GET /api/gifts` or `GET /api/gifts/catalog`
- **Response (200 OK):**
```json
{
  "status": true,
  "data": {
    "categories_list": [
      { "key": "all", "label": "All", "count": 160 },
      { "key": "hot", "label": "Hot", "count": 71 },
      { "key": "luxury", "label": "Luxury", "count": 15 }
    ],
    "gifts": [
      {
        "id": 1,
        "name": "Trophy Cup",
        "coin_price": 500,
        "category": "hot",
        "format": "svga",
        "icon_url": "https://chinchins.live/uploads/gifts/trophy.png",
        "animation_url": "https://chinchins.live/uploads/gifts/trophy.svga"
      }
    ]
  }
}
```

---

## 6. User Profile, Charm Level & Wallet APIs

### 6.1 Get User Profile
- **Endpoint:** `GET /api/profile/{id}` or `GET /api/profile?user_id={id}`
- **Response (200 OK):**
```json
{
  "status": true,
  "data": {
    "id": 2,
    "name": "Maya Model",
    "display_age": 23,
    "country": "Bangladesh",
    "country_flag": "🇧🇩",
    "online_status": "online",
    "video_call_rate": 100,
    "can_video_call": true,
    "charm_level": {
      "level": 2,
      "level_tag": "Lv.2",
      "progress": 25
    },
    "top_fan": {
      "id": 1,
      "name": "King David",
      "fan_coins": 8000
    },
    "summary": {
      "total_unique_gifts": 4,
      "total_items_count": 12,
      "total_coins": 12500,
      "formatted_coins": "12.5K"
    },
    "gifts_received": [
      {
        "gift_id": 5,
        "name": "Bengal Tiger",
        "quantity": 3,
        "total_coins": 6000
      }
    ]
  }
}
```

### 6.2 Get Wallet Balance
- **Endpoint:** `GET /api/wallet/balance` or `GET /api/user/balance`
- **Response (200 OK):**
```json
{
  "status": true,
  "coins": 8000,
  "earnings": 12500,
  "formatted_coins": "8K",
  "formatted_earnings": "12.5K"
}
```

---

## 7. WebSocket Reverb Channels & Event Catalog

### 7.1 Private Channels
| Channel Pattern | Subscription Requirement | Purpose |
|---|---|---|
| `private-user.{id}` / `user.{id}` | Auth Bearer Token | Incoming call ring alert, call accepted, missed call notification |
| `private-call.{call_id}` / `call.{call_id}` | Participant in Call | Pre-answer signaling (`call.accepted`, `call.rejected`, `call.ended`) |
| `stream.{room_name}` / `room.{room_name}` | Public / Viewer | Real-time gifts (`LiveGiftSentEvent`), viewer counts, in-room chat messages |
| `party.{room_id}` | Member in Room | Voice seat updates, speaking status, in-room gifts |

### 7.2 Event Catalog
| Broadcast Event Class | Broadcast Name (`broadcastAs`) | Payload Description |
|---|---|---|
| `CallAccepted` | `call.accepted` | `call_id`, `livekit_token`, `channel_name`, `status: connected` |
| `CallRejected` | `call.rejected` | `call_id`, `reason: busy/declined` |
| `CallCancelled` | `call.cancelled` | `call_id`, `reason: timeout_missed/caller_cancelled` |
| `CallEnded` | `call.ended` | `call_id`, `duration_seconds` |
| `LiveGiftSentEvent` | `live.gift.sent` | `gift_id`, `sender_id`, `receiver_id`, `quantity`, `animation_url` |
| `SeatUpdatedEvent` | `seat.updated` | `seat_index`, `user_id`, `is_speaking`, `is_muted` |

---
*End of RESTful API Specification. Tested and verified for 100% operational reliability.*
