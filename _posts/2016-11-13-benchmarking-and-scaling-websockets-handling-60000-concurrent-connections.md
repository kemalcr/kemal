---
title: 'Benchmarking and Scaling WebSockets: Handling 60000 concurrent connections'
date: '2016-11-13 22:03'
layout: 'post'
tags:
  - crystal
  - kemal
  - websocket
  - benchmark
  - tsung
post_author: Serdar Dogruyol
---

I love benchmarks but unfortunately

> Benchmarking is hard..

There are lots of good tools for benchmarking an HTTP server. Such as `ab`, `wrk`, `siege`.

My personal favorite is `wrk`. It's quite handy and simple to use for HTTP benchmarking.

## Benchmarking Websockets?

Back to original topic, my goal was:

> Benchmark how many concurrent WebSocket connections can a single [Kemal](http://kemalcr.com) application handle?

Unfortunately when you want to benchmark a WebSocket server there are actually nearly no resources / tools.

> There aren't many tools to benchmark WebSockets.

I actually asked this on Twitter and also got no response.

<blockquote class="twitter-tweet" data-lang="tr"><p lang="en" dir="ltr">Anyone know a fully featured tool for load testing / benchmarking WebSocket based web applications? <a href="https://twitter.com/hashtag/web?src=hash">#web</a> <a href="https://twitter.com/hashtag/benchmark?src=hash">#benchmark</a> <a href="https://twitter.com/hashtag/websocket?src=hash">#websocket</a></p>&mdash; Serdar Dogruyol セド (@sdogruyol) <a href="https://twitter.com/sdogruyol/status/797718960523382784">13 Kasım 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

Googling 'Benchmarking Websockets' gave me some results but most of them obsolete or not working anymore.

When i was just losing the hope, this post from [Elixir Phoenix Blog](http://www.phoenixframework.org/blog/the-road-to-2-million-websocket-connections) saved my day.

## Setup

### Kemal Server

A Kemal application implementing a simple chat server is just great for this benchmark. Luckily we have [kemal-chat](https://github.com/sdogruyol/kemal-chat). There's just one minor difference for this benchmark. Just turn off logging with

```
# src/kemal_chat.cr
logging false
```

You need to have Crystal `0.19.4` installed to build and run the server. Check [Crystal Installation Guide](https://crystal-lang.org/docs/installation/index.html) for more info.

```
git clone https://github.com/sdogruyol/kemal-chat
cd kemal-chat
crystal build --release src/kemal-chat.cr -o app
./app
```

Now go to your `IP_ADDRESS:3000/` and you should see something like this.

![Kemal Chat](/img/blog/kemal_chat.png)

### Tsung

[Tsung](http://tsung.erlang-projects.org/) is an open-source multi-protocol distributed load testing tool. It's written in [Erlang](http://www.erlang.org/).

Tsung also supports benchmarking WebSocket protocol. Tsung configuration and scenarios are written in `XML` (i know it's scary).

![You Said XML](/img/blog/you_said_xml.jpg)

Installing `Tsung` is straightforward but there's a pitfall. Be sure to use `Ubuntu 16.04`.

```
sudo apt-get update
sudo apt-get install tsung
tsung -v
1.5.1
```

Now that we have Tsung installed and ready to engage we need a configuration file. Like i said the configuration is in XML.

```xml
<?xml version="1.0"?>
<!DOCTYPE tsung SYSTEM "/user/share/tsung/tsung-1.0.dtd">
<tsung loglevel="notice" version="1.0">
  <clients>
    <client host="tsung-machine" use_controller_vm="false" maxusers="64000" />
    <client host="tsung-machine-2" use_controller_vm="false" maxusers="64000" />
  </clients>

  <servers>
    <server host="KEMAL_HOST_IP" port="3000" type="tcp" />
  </servers>

  <load>
    <arrivalphase phase="1" duration="100" unit="second">
      <users maxnumber="100000" arrivalrate="1000" unit="second" />
    </arrivalphase>
  </load>

  <sessions>
    <session name="websocket" probability="100" type="ts_websocket">
        <request>
             <websocket type="connect" path="/"></websocket>
        </request>

        <request subst="true">
            <websocket type="message">{"name":"Kemal"}</websocket>
        </request>

        <for var="i" from="1" to="100" incr="1">
          <thinktime value="10"/>
        </for>
    </session>
  </sessions>
</tsung>
```

This XML configuration seems a bit complicated. Here are the important things that you should be aware of.

- `<client>` is a Tsung machine. If you are running Tsung in a distributed mode (multiple Tsung servers) you need to edit your `/etc/hosts` and add your Tsung servers like this.

```
tsung-machine 95.85.57.196
tsung-machine-2 146.185.131.204
```

Tsung uses SSH authentication to access workers. That's why you need to generate a public key in your Tsung master machine in this case `tsung-machine` and add it to `tsung-machine-2`'s `.ssh/authorized_keys`.

On `tsung-machine`

```
ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (/home/tsung-machine/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/tsung-machine/.ssh/id_rsa.
Your public key has been saved in /home/tsung-machine/.ssh/id_rsa.pub.
cat id-rsa.pub
```

Copy the output of `cat`. On `tsung-machine-2`

```
vim .ssh/authorized_keys
```
And paste `tsung-machine`'s `id-rsa.pub`.

Now try to SSH into `tsung-machine-2` from `tsung-machine`.

Congrats, now you have a distributed `Tsung` cluster.

- `<server>` is your application. In this case it's our `Kemal` application.
- `<load>` specifies our load configuration. In this case we are going with 1000 users per second up to 100000 users for 100 seconds.
- `<session>` specifies your session scenario for each scenario. In this case we are going to open a ***WebSocket*** connection on `/` send a message with `{"name":"Kemal"}` body then hold the connection open for 1000 seconds(which is longer enough for our whole test).

Here is how our server cluster looks like.

![Go change the world](/img/blog/go_change_the_world.png)

## Benchmark

We got everything setup for our benchmark. Assuming that the configuration file is `websocket.xml`
here's what you need to run.

```
tsung -f websocket.xml start
```

### The first try

The first try actually didn't go well. I couldn't get Tsung to put enough load to push `Kemal` and just got 1k connections. Seemed like the default `Operating System` configurations were not enough.

### Configuring OS for high load

A quick research on how to make `Ubuntu 16.04` suitable for high connection / high load handed me these.

```
sysctl -w fs.file-max=1000000
sysctl -w fs.nr_open=1000000
ulimit -n 1000000
sysctl -w net.ipv4.tcp_mem='10000000 10000000 10000000'
sysctl -w net.ipv4.tcp_rmem='1024 4096 16384'
sysctl -w net.ipv4.tcp_wmem='1024 4096 16384'
sysctl -w net.core.rmem_max=16384
sysctl -w net.core.wmem_max=16384
```

I'm not going into details for but this configuration will allow Tsung to generate as much as load as possible.

### Again!

This time Tsung generated enough load to actually push Kemal to the limit.

<blockquote class="twitter-tweet" data-lang="tr"><p lang="en" dir="ltr">Kemal handles 28231 concurrent WebSocket connections on a  512 MB / 1 CPU <a href="https://twitter.com/digitalocean">@digitalocean</a> droplet <a href="https://t.co/nUnetmqgh4">pic.twitter.com/nUnetmqgh4</a></p>&mdash; Serdar Dogruyol セド (@sdogruyol) <a href="https://twitter.com/sdogruyol/status/797750500288499712">13 Kasım 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

### Time to upgrade Kemal server

Kemal server was a 1 CPU / 512 MB DigitalOcean droplet. Naturally i upgraded it to 2 CPU / 2 GB.

Running Tsung again gave me a surprise because i couldn't see any significant difference.

<blockquote class="twitter-tweet" data-lang="tr"><p lang="en" dir="ltr">My app instance running Kemal gets stuck at 29238 concurrent connections, it has more ram / cpu to spare. It&#39;s on Ubuntu 14.04. Any ideas?</p>&mdash; Serdar Dogruyol セド (@sdogruyol) <a href="https://twitter.com/sdogruyol/status/797784963508801537">13 Kasım 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

After some googling i found out that the default port ranges on `Ubuntu` was the limit.

```
sysctl -w net.ipv4.ip_local_port_range="1024 64000"
```

did the trick.

### Final results

Now that the OS is not the bottleneck Tsung
servers pushed the limits again :)

<blockquote class="twitter-tweet" data-lang="tr"><p lang="en" dir="ltr">Kemal handling 61189 concurrent WebSocket connections on a 2 GB server. This is not the limit but benchmarking is hard <a href="https://twitter.com/CrystalLanguage">@CrystalLanguage</a> <a href="https://t.co/y2GDow3J6e">pic.twitter.com/y2GDow3J6e</a></p>&mdash; Serdar Dogruyol セド (@sdogruyol) <a href="https://twitter.com/sdogruyol/status/797835943864573952">13 Kasım 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

Kemal Handling ***61189*** concurrent WebSocket connections :) It's not the limit but the end for now.

Happy Crystalling <3
