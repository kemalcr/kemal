require "kemal"

# Handle file uploads via POST request to /upload endpoint
post "/upload" do |env|
  # Get the uploaded file from the "image" field in the form
  # The file is initially stored in a temporary location
  uploaded_file = env.params.files["image"].tempfile

  # Construct the destination path where we'll save the file
  # - Kemal.config.public_folder is the configured public directory
  # - "uploads/" is the subdirectory where we'll store uploads
  # - File.basename gets just the filename from the temp file path
  uploaded_file_path = ::File.join [Kemal.config.public_folder, "uploads/", File.basename(uploaded_file.path)]

  # Open the destination file for writing and copy the uploaded file to it
  File.open(uploaded_file_path, "w") do |file|
    IO.copy(uploaded_file, file)
  end

  # Return a simple success message
  "Upload ok"
end

# Start the Kemal server
Kemal.run
