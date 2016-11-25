---
title: 'Kemal Organization and Modularization'
date: '2016-11-25 17:55'
layout: 'post'
tags:
  - crystal
  - kemal
post_author: Serdar Dogruyol
---

Happy Black Friday everyone!

On this special day we've got two great announcements to move Kemal forward.

# Kemal Organization

Finally, Kemal has moved to its' own organization under [kemalcr](http://github.com/kemalcr).

Having an organization will make collaboration much more easier and you can see the awesome team who make Kemal :)

![Kemal Organization](/img/blog/kemal_organization.png)

# Modularization

Some of you may have already noticed that under [Kemal Organization](http://github.com/kemalcr) there are several repos other than Kemal.

We've started to modularize Kemal. The main purpose of modularization is to keep Kemal itself as simple as possible with core functionalities.

Until now these features were in Kemal

- [Session](https://github.com/kemalcr/kemal-session)
- [CSRF](https://github.com/kemalcr/kemal-csrf)

These are not necessarily needed to run Kemal thus we seperated them from the core and moved to their own repositories. This really makes maintaining Kemal and these modules much more simpler. Meanwhile we're going to have more useful modules in the upcoming releases.

Let's make Kemal great together <3

Happy Crystalling!