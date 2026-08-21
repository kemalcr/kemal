---
name: kemal-upload
description: Handling file uploads and storage in Kemal using body size safety configuration and established project patterns.
license: MIT
---

# Kemal File Uploads & Storage

This skill provides expert guidance on implementing file uploads and storage in Kemal, with explicit safety bounds and validation, strictly following patterns from [`kemal-by-example/file-upload-storage`](https://github.com/sdogruyol/kemal-by-example/tree/master/file-upload-storage).

## Version Notes

- `Kemal.config.max_request_body_size`: since Kemal 1.9.
- `Kemal.config.max_multipart_form_field_size`: since Kemal 1.11.

## Core Mandates

- **Global Size Limit Configuration (Security in Kemal 1.9+ & 1.11+):** Set global request and multipart limits in the entrypoint file:

  ```crystal
  # Maximum overall request body size (Kemal 1.9+, e.g. 50MB)
  Kemal.config.max_request_body_size = 50 * 1024 * 1024

  # Maximum individual multipart form field size (Kemal 1.11+, e.g. 8MB)
  Kemal.config.max_multipart_form_field_size = 8 * 1024 * 1024
  ```

- **Uploading:** Use `env.params.files.has_key?("file")` to check for file presence, then `env.params.files["file"]` to access it:

  ```crystal
  unless env.params.files.has_key?("file")
    env.redirect "/files?error=Please+choose+a+file+to+upload."
    next ""
  end
  uploaded_file = env.params.files["file"]
  ```

- **Pre-Validation:** Check the size of the uploaded tempfile before storage:

  ```crystal
  max_size = 50_i64 * 1024 * 1024
  uploaded_file.tempfile.rewind
  tempfile_size = uploaded_file.tempfile.size

  if tempfile_size > max_size
    env.redirect "/files?error=File+size+must+be+50MB+or+smaller."
    next ""
  end
  ```

- **Extension Validation:** Check allowed extensions before processing:

  ```crystal
  unless StoredFile.allowed_extension?(original_name)
    env.redirect "/files?error=Only+images,+PDF,+and+TXT+files+are+allowed."
    next ""
  end
  ```

- **Handling Files:**

  ```crystal
  extension = ::File.extname(original_name).downcase
  stored_name = "#{Random::Secure.hex(16)}#{extension}"
  destination = ::File.join(Kemal.config.public_folder, "uploads", stored_name)

  ::File.open(destination, "w") do |file|
    IO.copy(uploaded_file.tempfile, file)
  end
  ```

- **MIME Type Detection:** Use a fallback for missing Content-Type headers:

  ```crystal
  mime_type = uploaded_file.headers["Content-Type"]? || "application/octet-stream"
  ```

- **File Deletion:** Always check existence before deleting:

  ```crystal
  ::File.delete(stored_file.storage_path) if ::File.exists?(stored_file.storage_path)
  ```

## Patterns from Source Code

### Upload Route (file-upload-storage/src/routes/files.cr)

```crystal
post "/files/upload" do |env|
  unless env.params.files.has_key?("file")
    env.redirect "/files?error=Please+choose+a+file+to+upload."
    next ""
  end

  uploaded_file = env.params.files["file"]
  original_name = uploaded_file.filename || "upload"

  unless StoredFile.allowed_extension?(original_name)
    env.redirect "/files?error=Only+images,+PDF,+and+TXT+files+are+allowed."
    next ""
  end

  max_size = 50_i64 * 1024 * 1024

  # Check size before copying:
  uploaded_file.tempfile.rewind
  tempfile_size = uploaded_file.tempfile.size

  if tempfile_size > max_size
    env.redirect "/files?error=File+size+must+be+50MB+or+smaller."
    next ""
  end

  extension = ::File.extname(original_name).downcase
  stored_name = "#{Random::Secure.hex(16)}#{extension}"
  destination = ::File.join(Kemal.config.public_folder, "uploads", stored_name)

  ::File.open(destination, "w") do |file|
    IO.copy(uploaded_file.tempfile, file)
  end

  mime_type = uploaded_file.headers["Content-Type"]? || "application/octet-stream"
  StoredFile.create(original_name, stored_name, mime_type, tempfile_size)

  env.redirect "/files?notice=File+uploaded+successfully."
end
```

### StoredFile Model with Extension Validation (file-upload-storage/src/models/stored_file.cr)

```crystal
class StoredFile
  include DB::Serializable

  ALLOWED_EXTENSIONS = %w[.jpg .jpeg .png .gif .pdf .txt]

  getter id : Int64?
  getter original_name : String
  getter stored_name : String
  getter mime_type : String
  getter size_bytes : Int64
  getter created_at : String

  def storage_path : String
    ::File.join(Kemal.config.public_folder, "uploads", stored_name)
  end

  def self.allowed_extension?(filename : String) : Bool
    ext = ::File.extname(filename).downcase
    ALLOWED_EXTENSIONS.includes?(ext)
  end
end
```

### File Deletion Route

```crystal
post "/files/:id/delete" do |env|
  id = env.params.url["id"]?.try(&.to_i64?)
  stored_file = id ? StoredFile.find(id) : nil

  if stored_file
    ::File.delete(stored_file.storage_path) if ::File.exists?(stored_file.storage_path)
    stored_file.delete
    env.redirect "/files?notice=File+deleted+successfully."
  else
    env.response.status = :not_found
    "File not found"
  end
end
```

## Best Practices

- **Configuration:** Always configure `Kemal.config.max_request_body_size` and `Kemal.config.max_multipart_form_field_size` globally to mitigate resource exhaustion / DoS attacks.
- **Extension Validation:** Use a helper like `StoredFile.allowed_extension?(name)` to validate extensions (e.g., `.jpg`, `.png`, `.pdf`, `.txt`).
- **Unique Storage Names:** Always generate unique filenames using `Random::Secure.hex(16)` to prevent collisions.
- **Cleanup:** Always use `::File.delete(path) if ::File.exists?(path)` when deleting files.
- **Early Validation:** Check file presence and extension before processing to fail fast.

## When to Use

- When implementing file upload features.
- When configuring Kemal to handle larger request bodies safely.
- When managing stored files (e.g., deleting after use).
