Routing multi-megabyte binary file uploads directly through API application servers is a recipe for memory exhaustion and worker thread starvation. [Certain] File uploads must be offloaded directly to object storage via pre-signed URLs with strict size and MIME-type limits, followed by asynchronous malware scanning before marking the object available.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Direct-to-Storage Upload Flow

```
initiateUpload(context, metadata) → uploadTicket                            ▶ + ⚙
├── authorize(principal, "files:write", targetFolder)            ⚠ 403
├── validateMetadata(type, declaredSize, filename)               ⚠ 400
├── createMetadataRecord(status: PENDING, tenantPath, fileId)    ⚙
├── issueSignedUploadUrl(fileId, ttl: 15m, maxSize, contentType) ⚙
│   └── Client uploads directly from browser to S3 / GCS (zero app server bandwidth)
└── return uploadTicket {fileId, uploadUrl, expiresAt}
```

---

## 2. Asynchronous Post-Upload Verification Pipeline

```
onUploadComplete(storageEvent) → verifiedFile                               ⚙
├── readStorageEvent(bucket, key, actualSize, etag)
├── verifySizeAndHash(actualSize, expectedRecord)                ⚠ → delete, mark REJECTED
├── scanForMalware(object) (ClamAV / VirusTotal scanner)         ⚠ → quarantine, alert
├── extractMetadata(imageDimensions, pdfPageCount)
├── setStatus(AVAILABLE)                                         ⚙
└── emit(file.uploaded)                                          ⚙
```

---

## 3. Secure Download Flow

```
getDownloadUrl(context, fileId) → signedUrl                                 ⚙
├── authorize(principal, "files:read", fileId)                   ⚠ 404
├── checkStatus(fileRecord) → must be AVAILABLE only             ⚠ 409
└── issueSignedDownloadUrl(fileId, shortTtl: 5m)                 ⚙
```

---

## 4. Strict File Storage Invariants

1. **Zero Direct Binary Proxying**: API gateways and microservices must never stream multipart file bytes through application memory. All file uploads and downloads must utilize pre-signed S3/GCS URLs.
2. **Mandatory Post-Upload Antivirus Scanning**: Newly uploaded files must remain in a `PENDING_SCAN` state and cannot be downloaded by other users until verified clean by asynchronous malware scanners.
3. **Automated Pending Cleanup**: Objects uploaded without confirmation or tickets that expire must be pruned automatically via object storage lifecycle policies (e.g. abort incomplete multipart uploads after 24h).

