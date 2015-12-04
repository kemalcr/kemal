# Kemal Tutorial

## Install Crystal

```
brew update
brew install crystal-lang
```

## Installing Kemal

You should create your application first:

```
crystal init app awesome_web_project
cd awesome_web_project
```

Then add *kemal* to the `shard.yml` file as a dependency.

```yml
dependencies:
  kemal:
    github: sdogruyol/kemal
    branch: master
```

You should run `shards` to get dependencies:

```
shards install
```

## Include Kemal into your project

Open `awesome_web_project/src/awesome_web_project.cr` and require `kemal` to use Kemal.

```ruby
require 'kemal'
```

## Hack your project

Do some awesome stuff with awesome Kemal.

```ruby
get "/" do
  "Hello World!"
end
```

## Run your awesome web project.

```
crystal build --release src/awesome_web_project.cr
./awesome_web_project
```

Now you can be happy with your new, very fast, readable web project.
