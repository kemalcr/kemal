module Kemal
  class Etag
    def self.add_header(headers : HTTP::Headers, etag : String) : Nil
      headers["ETag"] = etag
    end

    def self.matches?(headers : HTTP::Headers, etag : String) : Bool
      !!(headers["If-None-Match"]? && headers["If-None-Match"] == etag)
    end

    def self.from_file(file_path : String) : String
      %{W/"#{File.lstat(file_path).mtime.epoch.to_s}"}
    end

    def self.set_not_modified(response : HTTP::Server::Response) : Nil
      response.headers.delete "Content-Type"
      response.content_length = 0
      response.status_code = 304
    end
  end
end
