require "kemal"

# Handle file uploads via POST request to /upload endpoint
post "/upload" do |env|
  # Get the uploaded file from the "image" field in the form
  # It is spooled to a temporary file that is removed when the request is over
  uploaded_file = env.params.files["image"]

  # Construct the destination path where we'll save the file
  # - Kemal.config.public_folder is the configured public directory
  # - "uploads/" is the subdirectory where we'll store uploads
  # - File.basename gets just the filename from the temp file path
  uploaded_file_path = ::File.join [Kemal.config.public_folder, "uploads/", File.basename(uploaded_file.path)]

  # Copy the upload to its destination; `open` closes the upload when done
  uploaded_file.open do |upload|
    File.open(uploaded_file_path, "w") do |file|
      IO.copy(upload, file)
    end
  end

  # Return a simple success message
  "Upload ok"
end

# Start the Kemal server
Kemal.run
