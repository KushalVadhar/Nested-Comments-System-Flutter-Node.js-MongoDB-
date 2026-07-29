# Real-Time Nested Comments Application

A production-grade, cross-platform Flutter application backed by a Node.js REST API with WebSockets for real-time nested discussions.

---

## 🌐 Live Production Deployment

- **Live Backend Host**: Render Cloud (`https://nested-comments-system-flutter-node-js.onrender.com`)
- **Live REST API**: `https://nested-comments-system-flutter-node-js.onrender.com/api`
- **Live WebSocket Gateway**: `wss://nested-comments-system-flutter-node-js.onrender.com`
- **Database**: MongoDB Atlas Cloud Cluster

---

## 🌟 Key Features

1. **O(n) HashMap Tree Algorithm**: High-performance comment tree construction with an **orphan queue mechanism** that handles out-of-order comments arriving before their parent. Supports unlimited depth.
2. **Real-Time Live Sync via WebSocket**: Instant broadcast of new comments, replies, edits, soft deletions, and likes across all connected clients.
3. **Missed-Event Recovery (`eventId` Flow)**: Auto-reconnection with monotonic `eventId` tracking. Client fetches missed events seamlessly upon reconnect.
4. **Optimistic UI & Rollback**: Instant client-side insertions with temporary IDs. On server error, local node is safely rolled back without affecting siblings or ancestors.
5. **Cursor-Based Pagination & Live Reconciliation**: Cursor-based root pagination (`limit: 20`) with live deduplication against WebSocket events.
6. **Scoped Node Rebuilds**: State changes are scoped per-node via `Provider` and `Consumer` — WebSocket events for comment #47 do not trigger full-tree rebuilds.
7. **Debounced Interactions**: 300ms debounce on like/unlike toggles to prevent race conditions; 400ms server-side debounced search with inline text highlighting and auto-expanding ancestor chains.
8. **Soft Delete Tombstoning**: Deleted nodes with children remain tombstoned (`[deleted]`) to preserve descendant positions. Leaf nodes are removed completely.
9. **JWT Authentication & Rate Limiting**: Secure token-based auth with local secure storage persistence. Server-side middleware rate limits comment posting to 1 request per 3 seconds per user.

---

## 🏗️ Architecture Overview

```
 ┌─────────────────────────────────────────────────────────┐
 │                       Flutter App                       │
 │  ┌──────────────┐   ┌─────────────────┐  ┌───────────┐  │
 │  │ Screens & UI │ ◄─┤ Provider State  │ ◄┤ Models    │  │
 │  └──────────────┘   └────────┬────────┘  └───────────┘  │
 └──────────┬───────────────────┼──────────────────────────┘
            │ REST              │ WebSocket
            ▼                   ▼
 ┌─────────────────────────────────────────────────────────┐
 │               Node.js Backend (Render Cloud)            │
 │  ┌──────────────┐   ┌─────────────────┐  ┌───────────┐  │
 │  │ Express API  │   │ WebSocket (ws)  │  │ Middleware│  │
 │  └───────┬──────┘   └────────┬────────┘  └───────────┘  │
 └──────────┼───────────────────┼──────────────────────────┘
            │                   │
            ▼                   ▼
 ┌─────────────────────────────────────────────────────────┐
 │                MongoDB Database (Atlas Cloud)            │
 └─────────────────────────────────────────────────────────┘
```

---

## 💾 Where Message Data is Stored

The application stores and manages message data across 4 distinct layers:

### 1. Database Layer (Persistent Storage)
- **Database**: MongoDB Atlas Cloud Cluster.
- **Collection**: `comments`
- **Stored Data Structure**:
  ```json
  {
    "_id": "uuid-v4",
    "parentId": "uuid-v4 | null",
    "author": { "id": "uuid-v4", "username": "string" },
    "message": "string",
    "likes": 0,
    "likedBy": ["userId"],
    "isDeleted": false,
    "createdAt": "ISO8601 Timestamp",
    "editedAt": "ISO8601 Timestamp | null",
    "eventId": 42
  }
  ```

### 2. Backend Server Layer (In-Memory & Event Stream)
- Processed by Express controllers in [`backend/controllers/commentController.js`](file:///c:/Test_Project/Test_Project/backend/controllers/commentController.js).
- Transmitted live to connected clients via WebSockets in [`backend/websocket/wsHandler.js`](file:///c:/Test_Project/Test_Project/backend/websocket/wsHandler.js).

### 3. Flutter Client Layer (In-Memory Tree & UI State)
- Stored in-memory inside the `TreeBuilder` class ([`flutter_app/lib/utils/tree_algorithm.dart`](file:///c:/Test_Project/Test_Project/flutter_app/lib/utils/tree_algorithm.dart)):
  - `nodeMap`: `Map<String, CommentTreeNode>` ($O(1)$ fast lookup for node state and replies).
  - `orphanQueue`: `Map<String, List<CommentTreeNode>>` (holds child comments arriving before their parent).
  - `visibleNodes`: `List<CommentTreeNode>` (flattened 1D array passed to `ListView.builder` for lazy rendering).

### 4. Secure Local Device Storage (Session & Tokens)
- JWT Tokens & user session state are stored securely on the mobile device via `FlutterSecureStorage` ([`flutter_app/lib/services/storage_service.dart`](file:///c:/Test_Project/Test_Project/flutter_app/lib/services/storage_service.dart)):
  - **iOS**: Encrypted Keychain.
  - **Android**: EncryptedSharedPreferences / KeyStore.

---

## 🛠️ Technology Stack & Rationale

### Frontend: Flutter (Dart)
- **State Management (Provider)**: Selected for its lightweight footprint, dependency injection capabilities, and precise scoped rebuild control via `Selector` / `Consumer` widgets.
- **`web_socket_channel`**: Official Flutter WebSocket package supporting cross-platform real-time event streaming.
- **`flutter_secure_storage`**: Platform-native encrypted storage for JWT token persistence.

### Backend: Node.js (Express & `ws`)
- **Node.js + Express**: Event-driven asynchronous execution model ideal for handling concurrent WebSocket connections and lightweight REST endpoints. Hosted live on Render Cloud.
- **WebSocket (`ws`)**: Native WebSocket protocol without heavy Socket.io overhead, ensuring raw speed and standard protocol compatibility.

### Database: MongoDB Atlas
- **Rationale**: Nested comment hierarchies are document-oriented by nature. MongoDB's flexible schema and indexed query support (`parentId`, `eventId`, `createdAt`) make it highly performant for tree traversal and live event streaming.

---

## 📊 Database Schema & Indexes

### `comments` Collection
- `{ eventId: 1 }` (Unique) — Used for missed-event recovery queries.
- `{ parentId: 1, createdAt: -1 }` — Fast root & reply lookups.

### `users` Collection
- `_id`: UUID v4
- `username`: String (Unique)
- `password`: Hashed String (Bcrypt)

### `counters` Collection
- `_id`: String (`commentEventId`)
- `seq`: Monotonically increasing Integer counter

---

## 🚀 Setup & Execution Instructions

### Prerequisites
- Node.js (v18+)
- MongoDB Atlas Cluster URI or Local MongoDB
- Flutter SDK (v3.0.0+)

### 1. Backend Setup (Local / Cloud)
```bash
cd backend
npm install
```

Copy `backend/.env.example` to `backend/.env`:
```env
PORT=5000
MONGODB_URI=mongodb+srv://<username>:<password>@cluster0.rl3sxmm.mongodb.net/nested_comments_db?retryWrites=true&w=majority
JWT_SECRET=super_secret_jwt_key_comments_app_2026
NODE_ENV=development
```

Start the server:
```bash
npm start
```

Run backend tests:
```bash
npm test
```

### 2. Flutter App Setup
```bash
cd flutter_app
flutter pub get
```

Run tests:
```bash
flutter test
```

Run the application:
```bash
flutter run
```

---

## 💡 Key Algorithms & Design Details

### 1. Comment Tree Algorithm & Orphan Queue
Tree construction uses an $O(n)$ HashMap approach:
1. Maintain a `nodeMap` (`Map<id, CommentTreeNode>`) and an `orphanQueue` (`Map<parentId, List<CommentTreeNode>>`).
2. When a node arrives:
   - Insert into `nodeMap`.
   - Check `orphanQueue` for any waiting children whose `parentId` matches this node's `id`. If found, re-attach them immediately in a single pass.
   - Attach node to its parent if found, or place in `orphanQueue` if parent has not yet arrived.
3. Call `flattenVisibleNodes()` to generate a 1D list of visible nodes for lazy rendering in `ListView.builder`.

### 2. Real-Time Missed Event Recovery (`eventId` Flow)
- Every mutation (create, edit, delete, like) generates a strictly increasing `eventId` via a thread-safe MongoDB counter.
- Flutter tracks `lastKnownEventId`.
- Upon WebSocket reconnect, the app queries `GET /api/comments/events?since=lastKnownEventId` and applies all missed events sequentially.

### 3. Rate Limiting Middleware
- Server-side middleware restricts `POST /comments` to 1 request per 3 seconds per authenticated user using an in-memory timestamp map.
- Responds with `HTTP 429 Too Many Requests` when exceeded.

---

## 🧪 Testing Strategy

1. **Tree Algorithm Unit Tests** ([`test/tree_algorithm_test.dart`](file:///c:/Test_Project/Test_Project/flutter_app/test/tree_algorithm_test.dart)):
   - Verifies $O(n)$ tree building with unlimited depth.
   - Tests orphan queue re-attachment when child arrives before parent.
   - Validates soft-delete tombstoning vs hard-delete leaf removal.
   - Tests expand/collapse flattening.
2. **Widget Tests** ([`test/comment_node_widget_test.dart`](file:///c:/Test_Project/Test_Project/flutter_app/test/comment_node_widget_test.dart), [`test/comment_tree_widget_test.dart`](file:///c:/Test_Project/Test_Project/flutter_app/test/comment_tree_widget_test.dart)):
   - Tests rendering of `CommentNodeWidget` and `CommentTreeWidget`.
3. **Backend API Endpoint Tests** ([`backend/tests/comments.test.js`](file:///c:/Test_Project/Test_Project/backend/tests/comments.test.js)):
   - Tests registration, comment creation, like/unlike toggles, and cursor pagination.

---

## 🤖 AI Usage Disclosure

- **AI Assistance**: AI was utilized to assist with initial boilerplate creation, Android Gradle Plugin (AGP 8.3.2) / Java 17 migration troubleshooting, and formatting documentation.
- **Custom Developer Implementation**:
  - Custom $O(n)$ HashMap tree algorithm and orphan queue logic.
  - Missed event recovery mechanism via `eventId`.
  - Scoped node rebuild state management architecture.
  - Render Cloud Deployment & MongoDB Atlas Cloud integration.
