# GlowScan Mobile — Remaining Backend Gaps

The following mobile APIs are still unavailable in the current backend
contract. Routine, check-in, product detail, notification preferences, and
notification inbox are now implemented and integrated in the mobile app.

Success envelope:

```json
{ "status": 200, "message": "Success", "data": {} }
```

Errors must include a stable `code` field. Ownership always comes from the
bearer token; requests must never accept a `userId`.

## P1 — Analysis recovery and privacy

| Method | Route | Purpose |
| --- | --- | --- |
| `POST` | `/skin-analysis/:sessionId/retry` | Retry an eligible failed analysis. |
| `DELETE` | `/skin-analysis/:sessionId` | Delete the session and its source image. |
| `POST` | `/skin-analysis/:sessionId/report` | Report an incorrect or unsafe result. |

```json
{ "reason": "INCORRECT_RESULT", "note": "Optional feedback" }
```

Analysis status should expose image retention state:

```json
{
  "quality": { "accepted": true, "score": 0.91, "issues": [] },
  "retention": { "imageRetained": false, "deleteAvailable": true }
}
```

Deletion must delete the Cloudinary asset too, or expose a documented
asynchronous deletion job and reconciliation policy.

## P1 — Account data controls

| Method | Route | Purpose |
| --- | --- | --- |
| `POST` | `/account/export` | Create an account-data export job. |
| `GET` | `/account/export/:jobId` | Read export status and time-limited URL. |
| `POST` | `/account/delete/request` | Start account deletion. |
| `POST` | `/account/delete/confirm` | Confirm with a server-issued token. |

Retention must cover Cloudinary assets, devices, routines, analysis records,
and billing/audit obligations before this API is enabled.

## P2 — Google Calendar routine sync

| Method | Route |
| --- | --- |
| `POST` | `/calendar/connect` |
| `GET` | `/calendar/connection` |
| `DELETE` | `/calendar/connection` |
| `POST` | `/calendar/routine-sync` |

Use OAuth/native authorization exchange and idempotent sync jobs. A Gmail
address alone is never calendar-write authorization.

## Out of mobile scope

Payment and subscription flows remain website-owned. Do not expose admin
catalog or admin-account APIs to the mobile app.
