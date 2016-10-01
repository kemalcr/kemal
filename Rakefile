task :docs do
  puts "Build docs..."
  system "git checkout master > /dev/null 2>&1"
  system "crystal doc > /dev/null 2>&1"
  system "git checkout gh-pages > /dev/null 2>&1"
end