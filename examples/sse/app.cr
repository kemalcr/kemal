require "kemal"

sse "/events" do |stream, _|
  3.times do |i|
    stream.send("tick #{i + 1}", event: "tick", id: i + 1)
    sleep 1
  end
end

get "/" do
  <<-HTML
    <!DOCTYPE html>
    <html>
      <head><title>SSE Example</title></head>
      <body>
        <h1>Server-Sent Events</h1>
        <ul id="events"></ul>
        <script>
          const list = document.getElementById("events");
          const source = new EventSource("/events");
          source.addEventListener("tick", (event) => {
            const item = document.createElement("li");
            item.textContent = event.data;
            list.appendChild(item);
          });
        </script>
      </body>
    </html>
    HTML
end

Kemal.run
