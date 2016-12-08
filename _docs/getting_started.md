---
layout: doc
title: "Getting Started"
order: 1
---

## 1. Install Crystal

### OS X

```
brew update
brew install crystal-lang
```

### Debian / Ubuntu

```
curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
sudo apt-get install crystal
```

For other OSes and distros check the [official documentation](http://crystal-lang.org/docs/installation/on_debian_and_ubuntu.html).

## 2. Install Kemal

You should create your application first:

```
crystal init app your_app
cd your_app
```

Then add *kemal* to the `shard.yml` file as a dependency.

```
dependencies:
  kemal:
    github: kemalcr/kemal
    branch: master
```

You should run `shards` to get dependencies:

```
shards install
```

It will output something like that:

```
$ shards install
Updating https://github.com/kemalcr/kemal.git
Installing kemal (master)
```

## 3. Add Kemal

Open `your_app/src/your_app.cr` and require `kemal` to use Kemal.

```ruby
require "kemal"
```

## 4. Hack!

Do some awesome stuff with awesome Kemal.

```ruby
get "/" do
  "Hello World!"
end
```

All the code should look like this:

```ruby
require "kemal"

get "/" do
  "Hello World!"
end

Kemal.run
```

## 5. Run!

```
crystal build --release src/your_app.cr
./your_app
```

You should see some logs like these:

```
[development] Kemal is ready to lead at http://0.0.0.0:3000
2015-12-01 13:47:48 +0200 | 200 | GET / - (666µs)
2015-12-05 13:47:48 +0200 | 404 | GET /favicon.ico - (14µs)
```

Now you can be happy with your new, very fast, readable web project.
