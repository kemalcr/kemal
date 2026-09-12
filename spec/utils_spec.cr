require "./spec_helper"

describe Kemal::Utils do
  describe ".parse_accept_encoding" do
    it "reads codings and their qvalues" do
      Kemal::Utils.parse_accept_encoding("gzip;q=0.5, deflate").should eq({"gzip" => 0.5, "deflate" => 1.0})
    end

    it "defaults a coding without a qvalue to 1" do
      Kemal::Utils.parse_accept_encoding("gzip").should eq({"gzip" => 1.0})
    end

    it "lowercases coding names" do
      Kemal::Utils.parse_accept_encoding("GZIP, Deflate").should eq({"gzip" => 1.0, "deflate" => 1.0})
    end

    it "keeps the wildcard as a coding of its own" do
      Kemal::Utils.parse_accept_encoding("*;q=0").should eq({"*" => 0.0})
    end

    it "ignores whitespace around codings and parameters" do
      Kemal::Utils.parse_accept_encoding(" gzip ; q=0.8 , deflate ").should eq({"gzip" => 0.8, "deflate" => 1.0})
    end

    it "ignores parameters other than q" do
      Kemal::Utils.parse_accept_encoding("gzip;level=1;q=0.5;foo=bar").should eq({"gzip" => 0.5})
      Kemal::Utils.parse_accept_encoding("gzip;level=1").should eq({"gzip" => 1.0})
    end

    it "drops a coding whose qvalue is not a qvalue" do
      Kemal::Utils.parse_accept_encoding("gzip;q=abc, deflate").should eq({"deflate" => 1.0})
      Kemal::Utils.parse_accept_encoding("gzip;q=2").should be_empty
      Kemal::Utils.parse_accept_encoding("gzip;q=-1").should be_empty
      Kemal::Utils.parse_accept_encoding("gzip;q=").should be_empty
    end

    it "ignores empty list elements" do
      Kemal::Utils.parse_accept_encoding(", ,gzip,").should eq({"gzip" => 1.0})
      Kemal::Utils.parse_accept_encoding("").should be_empty
    end

    it "folds the x-gzip alias into gzip" do
      # RFC 9110 §8.4.1.3
      Kemal::Utils.parse_accept_encoding("x-gzip").should eq({"gzip" => 1.0})
      Kemal::Utils.parse_accept_encoding("X-Gzip;q=0, gzip").should eq({"gzip" => 0.0})
    end

    it "keeps the lowest qvalue of a coding listed more than once" do
      # A later duplicate must not undo a refusal.
      Kemal::Utils.parse_accept_encoding("gzip;q=0, gzip").should eq({"gzip" => 0.0})
      Kemal::Utils.parse_accept_encoding("gzip, gzip;q=0").should eq({"gzip" => 0.0})
    end
  end

  describe ".select_content_coding" do
    it "sends the stored bytes when the request states no preference" do
      Kemal::Utils.select_content_coding(nil).should eq("identity")
      Kemal::Utils.select_content_coding("").should eq("identity")
    end

    it "picks a coding the client accepts" do
      Kemal::Utils.select_content_coding("gzip").should eq("gzip")
      Kemal::Utils.select_content_coding("deflate").should eq("deflate")
      Kemal::Utils.select_content_coding("gzip, deflate, sdch, br").should eq("gzip")
    end

    it "prefers Kemal's own order between codings the client ranks equally" do
      Kemal::Utils.select_content_coding("deflate, gzip").should eq("gzip")
    end

    it "honors the qvalue order the client asked for" do
      Kemal::Utils.select_content_coding("deflate;q=1.0, gzip;q=0.5").should eq("deflate")
      Kemal::Utils.select_content_coding("deflate;q=0.5, gzip;q=1.0").should eq("gzip")
    end

    it "treats q=0 as a refusal of that coding" do
      Kemal::Utils.select_content_coding("gzip;q=0").should eq("identity")
      Kemal::Utils.select_content_coding("gzip;q=0, deflate").should eq("deflate")
      Kemal::Utils.select_content_coding("gzip;q=0, deflate;q=0").should eq("identity")
    end

    it "matches unlisted codings against the wildcard" do
      Kemal::Utils.select_content_coding("*").should eq("gzip")
      Kemal::Utils.select_content_coding("gzip;q=0, *").should eq("deflate")
      Kemal::Utils.select_content_coding("*;q=0, gzip").should eq("gzip")
    end

    it "reports that no coding at all is acceptable" do
      Kemal::Utils.select_content_coding("*;q=0").should be_nil
      Kemal::Utils.select_content_coding("identity;q=0").should be_nil
    end

    it "prefers a coding over an identity the client refused" do
      Kemal::Utils.select_content_coding("identity;q=0, gzip;q=0.1").should eq("gzip")
      Kemal::Utils.select_content_coding("*;q=0, deflate;q=0.1").should eq("deflate")
    end

    it "ranks an explicit identity against the other codings" do
      Kemal::Utils.select_content_coding("identity;q=1.0, gzip;q=0.5").should eq("identity")
      Kemal::Utils.select_content_coding("identity;q=0.5, gzip;q=1.0").should eq("gzip")
      Kemal::Utils.select_content_coding("identity, gzip").should eq("gzip")
    end

    it "sends the stored bytes when it can produce none of the listed codings" do
      Kemal::Utils.select_content_coding("br, zstd").should eq("identity")
    end

    it "matches coding names case-insensitively" do
      Kemal::Utils.select_content_coding("GZIP").should eq("gzip")
    end

    it "accepts x-gzip as a name for gzip" do
      Kemal::Utils.select_content_coding("x-gzip").should eq("gzip")
      Kemal::Utils.select_content_coding("x-gzip;q=0").should eq("identity")
    end

    it "chooses from the codings the caller offers" do
      Kemal::Utils.select_content_coding("br, gzip", available: {"br"}).should eq("br")
      Kemal::Utils.select_content_coding("gzip", available: {"br"}).should eq("identity")
    end
  end

  describe ".append_vary" do
    it "sets the header when there is none" do
      headers = HTTP::Headers.new
      Kemal::Utils.append_vary(headers, "Accept-Encoding")
      headers["Vary"].should eq("Accept-Encoding")
    end

    it "keeps the fields already listed" do
      headers = HTTP::Headers{"Vary" => "Accept-Language"}
      Kemal::Utils.append_vary(headers, "Accept-Encoding")
      headers["Vary"].should eq("Accept-Language, Accept-Encoding")
    end

    it "does not list a field twice" do
      headers = HTTP::Headers{"Vary" => "Accept-Language, accept-encoding"}
      Kemal::Utils.append_vary(headers, "Accept-Encoding")
      headers["Vary"].should eq("Accept-Language, accept-encoding")
    end

    it "leaves a wildcard alone" do
      headers = HTTP::Headers{"Vary" => "*"}
      Kemal::Utils.append_vary(headers, "Accept-Encoding")
      headers["Vary"].should eq("*")
    end

    it "replaces an empty value" do
      headers = HTTP::Headers{"Vary" => ""}
      Kemal::Utils.append_vary(headers, "Accept-Encoding")
      headers["Vary"].should eq("Accept-Encoding")
    end
  end

  describe ".etag_with_coding" do
    it "marks the encoded form of a representation" do
      Kemal::Utils.etag_with_coding(%(W/"1700000000"), "gzip").should eq(%(W/"1700000000-gzip"))
      Kemal::Utils.etag_with_coding(%("1700000000"), "deflate").should eq(%("1700000000-deflate"))
    end

    it "leaves unquoted tags alone" do
      Kemal::Utils.etag_with_coding("W/1700000000", "gzip").should eq("W/1700000000")
    end

    it "leaves a coding it cannot reproduce alone" do
      # A tag Kemal cannot rebuild is one it can never match again on revalidation.
      Kemal::Utils.etag_with_coding(%(W/"1700000000"), "identity").should eq(%(W/"1700000000"))
      Kemal::Utils.etag_with_coding(%(W/"1700000000"), "br").should eq(%(W/"1700000000"))
      Kemal::Utils.etag_with_coding(%(W/"1700000000"), "gzip, br").should eq(%(W/"1700000000"))
    end
  end

  {% unless flag?(:without_zlib) %}
    describe ".compressible?" do
      it "follows the gzip option of serve_static" do
        previous = Kemal.config.serve_static

        begin
          serve_static({"gzip" => true})
          Kemal::Utils.compressible?("app.js", 1000).should be_true

          # Too small to be worth the framing, and a media type that is already compressed.
          Kemal::Utils.compressible?("app.js", 100).should be_false
          Kemal::Utils.compressible?("photo.png", 1000).should be_false

          serve_static({"gzip" => false})
          Kemal::Utils.compressible?("app.js", 1000).should be_false

          serve_static true
          Kemal::Utils.compressible?("app.js", 1000).should be_false
        ensure
          Kemal.config.serve_static = previous
        end
      end
    end
  {% end %}

  describe ".content_disposition" do
    it "quotes a plain ASCII name as it is" do
      Kemal::Utils.content_disposition("attachment", "report.pdf").should eq(%(attachment; filename="report.pdf"))
      Kemal::Utils.content_disposition("inline", "a b.txt").should eq(%(inline; filename="a b.txt"))
    end

    it "escapes the quote and the backslash inside the quoted-string" do
      # An unescaped `"` ended the parameter early: `filename="report "final".pdf"`.
      Kemal::Utils.content_disposition("attachment", %(report "final".pdf)).should eq(%q(attachment; filename="report \"final\".pdf"))
      Kemal::Utils.content_disposition("attachment", %q(back\slash.txt)).should eq(%q(attachment; filename="back\\slash.txt"))
    end

    it "adds an RFC 8187 filename* for a name outside ASCII" do
      Kemal::Utils.content_disposition("attachment", "rapor ünlü.pdf")
        .should eq(%(attachment; filename="rapor _nl_.pdf"; filename*=UTF-8''rapor%20%C3%BCnl%C3%BC.pdf))
    end

    it "keeps control characters out of the header" do
      # A CR/LF in the name used to make the stdlib reject the header, a 500.
      Kemal::Utils.content_disposition("attachment", "line\r\nX: 1.txt")
        .should eq(%(attachment; filename="line__X: 1.txt"; filename*=UTF-8''line%0D%0AX%3A%201.txt))
    end
  end

  describe ".valid_method?" do
    it "accepts the standard methods" do
      %w[GET HEAD POST PUT PATCH DELETE OPTIONS TRACE CONNECT QUERY].each do |method|
        Kemal::Utils.valid_method?(method).should be_true
      end
    end

    it "accepts an unfamiliar method that is still a token" do
      Kemal::Utils.valid_method?("PROPFIND").should be_true
      Kemal::Utils.valid_method?("X-CUSTOM_1.0!").should be_true
    end

    it "rejects an empty method" do
      Kemal::Utils.valid_method?("").should be_false
    end

    # The one that closes the route key desync: `/` is not a token character,
    # so a method can no longer absorb a segment of the path (#820).
    it "rejects a method carrying the router's separator" do
      Kemal::Utils.valid_method?("GET/admin").should be_false
      Kemal::Utils.valid_method?("/GET").should be_false
    end

    it "rejects separators, whitespace and control characters" do
      ["GET POST", "GET\t", "GET\r\n", "GET;x", "GET(x)", "GET\u0000", "GÉT"].each do |method|
        Kemal::Utils.valid_method?(method).should be_false
      end
    end
  end
end
