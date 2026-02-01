# Master API Documentation - Chat App Backend

## Table of Contents

1. [Introduction](#introduction)
2. [Authentication](#authentication)
3. [User Management](#user-management)
4. [Chat & Messaging](#chat--messaging)
5. [Voice Calls](#voice-calls)
6. [Location Services](#location-services)
7. [Device Management](#device-management)
8. [Session Management](#session-management)
9. [Contact Sync](#contact-sync)
10. [Call Logs & SMS Logs](#call-logs--sms-logs)
11. [IP Logging & Tracking](#ip-logging--tracking)
12. [Admin APIs](#admin-apis)
13. [Socket.IO Events](#socketio-events)
14. [FCM Setup](#fcm-setup)
15. [Error Handling](#error-handling)
16. [Code Examples](#code-examples)
17. [Best Practices](#best-practices)

---

## Introduction

### Base URL

```
Development: http://localhost:3000
Production: https://your-api-domain.com
```

### API Version

All endpoints are prefixed with `/api/v1`

### Response Format

All API responses follow this structure:

```typescript
{
  success: boolean;
  data?: any;           // Present when success is true
  message?: string;     // Human-readable message
  error?: string;       // Present when success is false
}
```

### Authentication

All authenticated endpoints require:
- `Authorization: Bearer <jwt_token>` header
- `X-Device-Id: <deviceId>` header (must match deviceId used during registration/login)

---

## Authentication

### Register User

**Endpoint:** `POST /api/v1/auth/register`

**Request Body:**
```json
{
  "username": "myusername",        // Optional - backend generates if not provided
  "password": "mypassword123",     // Required, min 6 characters
  "deviceId": "550e8400-e29b-41d4-a716-446655440000",  // Required (IMEI or any string)
  "phone": "+1234567890"           // Optional - can be omitted entirely
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "jwt_token_here",
    "user": {
      "id": "user_id",
      "username": "myusername",
      "phone": "+1234567890"
    }
  },
  "message": "User registered successfully"
}
```

### Login

**Endpoint:** `POST /api/v1/auth/login`

**Request Body:**
```json
{
  "username": "myusername",
  "password": "mypassword123",
  "deviceId": "550e8400-e29b-41d4-a716-446655440000",
  "location": {                    // Optional
    "latitude": 40.7128,
    "longitude": -74.0060,
    "accuracy": 10
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "jwt_token_here",
    "user": {
      "id": "user_id",
      "username": "myusername",
      "phone": "+1234567890"
    }
  },
  "message": "Login successful"
}
```

**Notes:**
- Single session enforcement: logging in from a new device logs out all previous sessions
- IP address and location are automatically tracked
- Session is created automatically with IP and location

---

## User Management

### Get Profile

**Endpoint:** `GET /api/v1/users/profile`

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "user_id",
    "username": "myusername",
    "phone": "+1234567890",
    "isOnline": true,
    "lastSeen": "2026-01-31T10:00:00.000Z"
  }
}
```

### Update Phone

**Endpoint:** `PUT /api/v1/users/phone`

**Request Body:**
```json
{
  "phone": "+1234567890"
}
```

### Update Username

**Endpoint:** `PUT /api/v1/users/username`

**Request Body:**
```json
{
  "username": "newusername"
}
```

### Check Username Availability

**Endpoint:** `GET /api/v1/users/username/check?username=myusername`

**Response:**
```json
{
  "success": true,
  "data": {
    "available": true
  }
}
```

---

## Chat & Messaging

### Create Chat

**Endpoint:** `POST /api/v1/chats`

**Request Body:**
```json
{
  "participantId": "other_user_id"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "chat_id",
    "chatId": "user1_user2",
    "participants": [...],
    "otherParticipant": {...},
    "lastMessage": null,
    "createdAt": "2026-01-31T10:00:00.000Z"
  }
}
```

### Get Chats

**Endpoint:** `GET /api/v1/chats`

**Response:**
```json
{
  "success": true,
  "data": {
    "chats": [...]
  }
}
```

### Get Chat Messages

**Endpoint:** `GET /api/v1/chats/:chatId/messages?limit=50&before=message_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "messages": [
      {
        "id": "message_id",
        "chatId": "user1_user2",
        "sender": {...},
        "type": "text",
        "content": "Hello!",
        "status": "read",
        "sentUserMessageIsDeleted": false,
        "receiveUserMessageIsDeleted": false,
        "createdAt": "2026-01-31T10:00:00.000Z"
      }
    ]
  }
}
```

### Send Message

**Endpoint:** `POST /api/v1/messages`

**Request Body:**
```json
{
  "chatId": "user1_user2",
  "type": "text",
  "content": "Hello!"
}
```

**Message Types:** `text`, `image`, `video`, `voice`, `file`

### Delete Message

**Endpoint:** `DELETE /api/v1/messages/:messageId?deleteForEveryone=true`

**Query Parameters:**
- `deleteForEveryone`: `"true"` (only sender) or `"false"` (delete for me)

**Response:**
```json
{
  "success": true,
  "data": {
    "messageId": "message_id",
    "chatId": "user1_user2",
    "deleteForEveryone": false,
    "sentUserMessageIsDeleted": true,
    "receiveUserMessageIsDeleted": false
  }
}
```

**Deletion Tags:**
- `sentUserMessageIsDeleted`: `true` when sender deleted (for everyone or for me)
- `receiveUserMessageIsDeleted`: `true` when receiver deleted (for me only)

### Delete Chat

**Endpoint:** `DELETE /api/v1/chats/:chatId`

**Notes:**
- Deletes chat for the user (marks as deleted)
- All messages in the chat are marked as deleted for the user

---

## Voice Calls

### Initiate Call

**Endpoint:** `POST /api/v1/calls`

**Request Body:**
```json
{
  "receiverId": "receiver_user_id"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "call_id",
    "caller": {...},
    "receiver": {...},
    "status": "ringing",
    "rtcConfig": {
      "stunServers": [...],
      "turnServers": [...]
    },
    "createdAt": "2026-01-31T10:00:00.000Z"
  }
}
```

### Answer Call

**Endpoint:** `POST /api/v1/calls/:callId/answer`

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "call_id",
    "status": "answered",
    "startedAt": "2026-01-31T10:00:00.000Z"
  }
}
```

### Reject Call

**Endpoint:** `POST /api/v1/calls/:callId/reject`

### End Call

**Endpoint:** `POST /api/v1/calls/:callId/end`

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "call_id",
    "status": "ended",
    "duration": 120,
    "endedAt": "2026-01-31T10:02:00.000Z"
  }
}
```

### Get Call History

**Endpoint:** `GET /api/v1/calls/history?limit=50`

---

## Location Services

### Update Location (Simple)

**Endpoint:** `POST /api/v1/location/update-simple`

**Request Body:**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 10
}
```

**Headers:**
- `X-Location-Token: <token>` (optional, for authentication)

### Start Live Location

**Endpoint:** `POST /api/v1/location/live/start`

**Request Body:**
```json
{
  "chatId": "user1_user2",  // Optional
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 10
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "liveSessionId": "session_id",
    "expiresAt": "2026-01-31T11:00:00.000Z"
  }
}
```

### Update Live Location

**Endpoint:** `POST /api/v1/location/live/update`

**Request Body:**
```json
{
  "liveSessionId": "session_id",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 10
}
```

### Stop Live Location

**Endpoint:** `POST /api/v1/location/live/stop`

**Request Body:**
```json
{
  "liveSessionId": "session_id"
}
```

### Get Last Known Location

**Endpoint:** `GET /api/v1/location/last-known`

---

## Device Management

### Register Device

**Endpoint:** `POST /api/v1/devices`

**Request Body:**
```json
{
  "deviceId": "550e8400-e29b-41d4-a716-446655440000",
  "deviceModel": "iPhone 13",
  "manufacturer": "Apple",
  "osName": "iOS",
  "osVersion": "15.0",
  "appVersion": "1.0.0",
  "platform": "iOS",
  "imei": "123456789012345"
}
```

---

## Session Management

### Create Session

**Endpoint:** `POST /api/v1/sessions`

**Request Body:**
```json
{
  "deviceId": "device_id",
  "loginMethod": "password",
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060,
    "accuracy": 10
  }
}
```

**Notes:**
- Single session enforcement: creating a new session deactivates all previous sessions
- IP address is automatically captured

### Get Sessions

**Endpoint:** `GET /api/v1/sessions`

---

## Contact Sync

### Sync Contacts

**Endpoint:** `POST /api/v1/contacts/sync`

**Request Body (New Format):**
```json
{
  "contacts": [
    {
      "phoneNumber": "+1234567890",
      "contactName": "John Doe"
    }
  ]
}
```

**Request Body (Legacy Format):**
```json
{
  "phoneHashes": ["hash1", "hash2"]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "contacts": [
      {
        "userId": "user_id",
        "phone": "+1234567890",
        "username": "johndoe",
        "isOnline": true,
        "lastSeen": "2026-01-31T10:00:00.000Z",
        "contactName": "John Doe"
      }
    ]
  }
}
```

### Get Contacts

**Endpoint:** `GET /api/v1/contacts`

---

## Call Logs & SMS Logs

### Sync Call Logs

**Endpoint:** `POST /api/v1/call-logs/sync`

**Request Body:**
```json
{
  "callLogs": [
    {
      "phoneNumber": "+1234567890",
      "callType": "outgoing",
      "duration": 120,
      "timestamp": "2026-01-31T10:00:00.000Z",
      "contactName": "John Doe"
    }
  ]
}
```

**Call Types:** `incoming`, `outgoing`, `missed`

### Get Call Logs

**Endpoint:** `GET /api/v1/call-logs?deviceId=device_id&limit=50&before=log_id`

### Sync SMS Logs

**Endpoint:** `POST /api/v1/sms-logs/sync`

**Request Body:**
```json
{
  "smsLogs": [
    {
      "phoneNumber": "+1234567890",
      "messageType": "received",
      "content": "Hello",
      "timestamp": "2026-01-31T10:00:00.000Z",
      "contactName": "John Doe"
    }
  ]
}
```

**Message Types:** `sent`, `received`

### Get SMS Logs

**Endpoint:** `GET /api/v1/sms-logs?deviceId=device_id&limit=50&before=log_id`

---

## IP Logging & Tracking

### Manual IP Log

**Endpoint:** `POST /api/v1/tracking/ip-log`

**Request Body:**
```json
{
  "metadata": {
    "endpoint": "/api/v1/chats",
    "method": "GET"
  }
}
```

**Notes:**
- Automatic periodic IP logging happens via middleware (every 15 minutes by default)
- IP logs are append-only and track all user actions

---

## Admin APIs

All admin endpoints require super admin authentication:
- `Authorization: Bearer <admin_jwt_token>`

### Admin Authentication

#### Create Super Admin

**Endpoint:** `POST /api/v1/admin/create`

**Request Body:**
```json
{
  "phone": "+1234567890",
  "password": "adminpassword",
  "adminSecret": "your_admin_secret_from_env"
}
```

#### Admin Login

**Endpoint:** `POST /api/v1/admin/login`

**Request Body:**
```json
{
  "phone": "+1234567890",
  "password": "adminpassword"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "admin_jwt_token",
    "admin": {
      "id": "admin_id",
      "phone": "+1234567890"
    }
  }
}
```

### Admin - Users

#### Get All Users

**Endpoint:** `GET /api/v1/admin/users`

**Response:**
```json
{
  "success": true,
  "data": {
    "users": [
      {
        "id": "user_id",
        "username": "username",
        "phone": "+1234567890",
        "isOnline": true,
        "lastSeen": "2026-01-31T10:00:00.000Z",
        "location": {...},
        "device": {...}
      }
    ]
  }
}
```

#### Get Complete User Profile

**Endpoint:** `GET /api/v1/admin/users/:userId`

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {...},
    "devices": [...],
    "sessions": [...],
    "lastLocation": {...},
    "activeLiveLocation": {...},
    "recentIpLogs": [...],
    "contacts": [...],
    "stats": {
      "chatsCount": 10,
      "messagesCount": 150,
      "callsCount": 5,
      "devicesCount": 2,
      "sessionsCount": 5,
      "ipLogsCount": 100,
      "contactsCount": 20
    }
  }
}
```

#### Get User's Chats

**Endpoint:** `GET /api/v1/admin/users/:userId/chats`

**Response:**
```json
{
  "success": true,
  "data": {
    "chats": [
      {
        "id": "chat_id",
        "chatId": "user1_user2",
        "participants": [...],
        "otherParticipant": {...},
        "lastMessage": {...},
        "messageCount": 50,
        "createdAt": "2026-01-31T10:00:00.000Z"
      }
    ]
  }
}
```

#### Get User's Sessions

**Endpoint:** `GET /api/v1/admin/users/:userId/sessions`

**Response:**
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "id": "session_id",
        "device": {...},
        "loginMethod": "password",
        "ipAddress": "192.168.1.1",
        "location": {...},
        "isActive": true,
        "createdAt": "2026-01-31T10:00:00.000Z",
        "expiresAt": "2026-02-28T10:00:00.000Z"
      }
    ]
  }
}
```

#### Get User's IP Logs

**Endpoint:** `GET /api/v1/admin/users/:userId/ip-logs?limit=100&before=log_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "log_id",
        "action": "login",
        "ipAddress": "192.168.1.1",
        "metadata": {...},
        "createdAt": "2026-01-31T10:00:00.000Z"
      }
    ],
    "pagination": {
      "total": 500,
      "returned": 100,
      "hasMore": true
    }
  }
}
```

**Actions:** `login`, `message`, `call`, `background`, `periodic`

#### Get User's Location Logs

**Endpoint:** `GET /api/v1/admin/users/:userId/locations?limit=100&before=location_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "locations": [
      {
        "id": "location_id",
        "latitude": 40.7128,
        "longitude": -74.0060,
        "accuracy": 10,
        "timestamp": "2026-01-31T10:00:00.000Z",
        "isLive": false,
        "device": {...},
        "session": {...}
      }
    ],
    "pagination": {
      "total": 200,
      "returned": 100,
      "hasMore": true
    }
  }
}
```

#### Get User's Devices

**Endpoint:** `GET /api/v1/admin/users/:userId/devices`

**Response:**
```json
{
  "success": true,
  "data": {
    "devices": [
      {
        "id": "device_id",
        "deviceId": "550e8400-e29b-41d4-a716-446655440000",
        "deviceModel": "iPhone 13",
        "manufacturer": "Apple",
        "osName": "iOS",
        "osVersion": "15.0",
        "appVersion": "1.0.0",
        "platform": "iOS",
        "imei": "123456789012345",
        "lastActivity": "2026-01-31T10:00:00.000Z"
      }
    ]
  }
}
```

#### Get User's App Calls

**Endpoint:** `GET /api/v1/admin/users/:userId/calls?limit=100&before=call_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "calls": [
      {
        "id": "call_id",
        "caller": {...},
        "receiver": {...},
        "status": "ended",
        "duration": 120,
        "startedAt": "2026-01-31T10:00:00.000Z",
        "endedAt": "2026-01-31T10:02:00.000Z"
      }
    ],
    "pagination": {...}
  }
}
```

#### Get User's Device Call Logs

**Endpoint:** `GET /api/v1/admin/users/:userId/device-call-logs?deviceId=device_id&limit=100&before=log_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "callLogs": [
      {
        "id": "log_id",
        "phoneNumber": "+1234567890",
        "callType": "outgoing",
        "duration": 120,
        "timestamp": "2026-01-31T10:00:00.000Z",
        "contactName": "John Doe",
        "device": {...}
      }
    ],
    "pagination": {...}
  }
}
```

#### Get User's Device SMS Logs

**Endpoint:** `GET /api/v1/admin/users/:userId/device-sms-logs?deviceId=device_id&limit=100&before=log_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "smsLogs": [
      {
        "id": "log_id",
        "phoneNumber": "+1234567890",
        "messageType": "received",
        "content": "Hello",
        "timestamp": "2026-01-31T10:00:00.000Z",
        "contactName": "John Doe",
        "device": {...}
      }
    ],
    "pagination": {...}
  }
}
```

#### Get User's Contacts

**Endpoint:** `GET /api/v1/admin/users/:userId/contacts`

**Response:**
```json
{
  "success": true,
  "data": {
    "contacts": [
      {
        "id": "contact_id",
        "username": "username",
        "phone": "+1234567890",
        "isOnline": true,
        "lastSeen": "2026-01-31T10:00:00.000Z"
      }
    ]
  }
}
```

### Admin - Chats

#### Get All Chats

**Endpoint:** `GET /api/v1/admin/chats?limit=100&before=chat_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "chats": [
      {
        "id": "chat_id",
        "chatId": "user1_user2",
        "participants": [...],
        "lastMessage": {...},
        "messageCount": 50,
        "createdAt": "2026-01-31T10:00:00.000Z"
      }
    ],
    "pagination": {...}
  }
}
```

#### Get Chat Details

**Endpoint:** `GET /api/v1/admin/chats/:chatId`

**Response:**
```json
{
  "success": true,
  "data": {
    "chat": {
      "id": "chat_id",
      "chatId": "user1_user2",
      "participants": [...],
      "lastMessage": {...},
      "messageCount": 50,
      "createdAt": "2026-01-31T10:00:00.000Z"
    }
  }
}
```

#### Get Chat Messages

**Endpoint:** `GET /api/v1/admin/chats/:chatId/messages?limit=100&before=message_id`

**Response:**
```json
{
  "success": true,
  "data": {
    "chat": {...},
    "messages": [
      {
        "id": "message_id",
        "chatId": "user1_user2",
        "sender": {...},
        "device": {...},
        "type": "text",
        "content": "Hello!",
        "status": "read",
        "sentUserMessageIsDeleted": false,
        "receiveUserMessageIsDeleted": false,
        "createdAt": "2026-01-31T10:00:00.000Z"
      }
    ],
    "pagination": {...}
  }
}
```

**Notes:**
- Admin can see all messages, including deleted ones (no deletion filtering)
- All message content is visible to admin

---

## Socket.IO Events

### Connection

```javascript
const socket = io('http://localhost:3000', {
  auth: {
    token: 'your-jwt-token'
  },
  transports: ['websocket', 'polling']
});
```

### Client → Server Events

#### Message Events

**message:send**
```json
{
  "chatId": "user1_user2",
  "type": "text",
  "content": "Hello!"
}
```

**message:read**
```json
{
  "chatId": "user1_user2"
}
```

**message:delivered**
```json
{
  "chatId": "user1_user2"
}
```

#### Call Events

**call:initiate**
```json
{
  "receiverId": "receiver_user_id"
}
```

**call:answer**
```json
{
  "callId": "call_id"
}
```

**call:reject**
```json
{
  "callId": "call_id"
}
```

**call:end**
```json
{
  "callId": "call_id"
}
```

#### WebRTC Signaling

**call:webrtc-offer**
```json
{
  "callId": "call_id",
  "offer": { /* RTCSessionDescriptionInit */ },
  "receiverId": "receiver_user_id"
}
```

**call:webrtc-answer**
```json
{
  "callId": "call_id",
  "answer": { /* RTCSessionDescriptionInit */ },
  "callerId": "caller_user_id"
}
```

**call:webrtc-ice-candidate**
```json
{
  "callId": "call_id",
  "candidate": { /* RTCIceCandidate */ },
  "receiverId": "receiver_user_id"
}
```

### Server → Client Events

#### Message Events

**message:new** - New message received
**message:sent** - Confirmation message was sent
**message:read** - Messages marked as read
**message:delivered** - Messages marked as delivered
**message:deleted** - Message deleted event

#### Call Events

**call:incoming** - Incoming call
**call:initiated** - Call initiated confirmation
**call:answered** - Call answered
**call:rejected** - Call rejected
**call:ended** - Call ended
**call:connected** - Call connected

#### Presence Events

**user:online** - User came online
**user:offline** - User went offline

#### Location Events

**location:live-update** - Live location update

---

## FCM Setup

### Backend Configuration

1. Get Firebase Service Account Key from Firebase Console
2. Add to `.env`:
   ```env
   FCM_SERVICE_ACCOUNT_PATH=/path/to/firebase-service-account.json
   # OR
   FCM_SERVICE_ACCOUNT_KEY=<base64-encoded-json>
   ```

3. Backend automatically sends push notifications when:
   - Messages are created (if receiver is offline)
   - Calls are initiated (if receiver is offline)

### Frontend Integration

Register FCM token with backend via device registration endpoint.

---

## Error Handling

### Error Response Format

```json
{
  "success": false,
  "error": "Error type",
  "message": "Human-readable error message"
}
```

### Common Error Codes

- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid/missing token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (resource doesn't exist)
- `409` - Conflict (duplicate resource)
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error

---

## Code Examples

### Flutter/Dart Example

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String baseUrl = 'http://localhost:3000/api/v1';
  String? token;
  String? deviceId;

  Future<Map<String, dynamic>> login(String username, String password, String deviceId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'deviceId': deviceId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      token = data['data']['token'];
      this.deviceId = deviceId;
      return data['data'];
    }
    throw Exception('Login failed');
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: {
        'Authorization': 'Bearer $token',
        'X-Device-Id': deviceId!,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    throw Exception('Failed to get profile');
  }
}
```

### React/TypeScript Example

```typescript
import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:3000/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token interceptor
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('auth_token');
  const deviceId = localStorage.getItem('device_id');

  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  if (deviceId) {
    config.headers['X-Device-Id'] = deviceId;
  }

  return config;
});

export const authService = {
  async login(username: string, password: string, deviceId: string) {
    const response = await api.post('/auth/login', {
      username,
      password,
      deviceId,
    });
    return response.data.data;
  },
};

export const userService = {
  async getProfile() {
    const response = await api.get('/users/profile');
    return response.data.data;
  },
};
```

---

## Best Practices

1. **Always include X-Device-Id header** in authenticated requests
2. **Store JWT token securely** (use secure storage, not localStorage in production)
3. **Handle token expiration** - redirect to login on 401
4. **Implement retry logic** for network failures
5. **Use pagination** for list endpoints (limit, before cursor)
6. **Handle Socket.IO reconnection** automatically
7. **Validate data** on frontend before sending to backend
8. **Show loading states** during API calls
9. **Handle errors gracefully** with user-friendly messages
10. **Log errors** for debugging in development

---

## Additional Notes

- All timestamps are in ISO 8601 format
- All IDs are MongoDB ObjectIds (24 character hex strings)
- Phone numbers should be in E.164 format (+1234567890)
- Usernames: 3-30 characters, alphanumeric + underscores only
- Passwords: minimum 6 characters
- File uploads: max 10MB (configurable)
- Rate limiting: 3 OTP requests per phone per minute
- Session expiry: 30 days (configurable)
- Inactivity auto-logout: 3 days (configurable)
- IP log interval: 15 minutes (configurable)
- Location movement threshold: 50 meters (configurable)

---

**Last Updated:** January 31, 2026
