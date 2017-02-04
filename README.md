# TitanOfOld's Gentoo Developer Overlay #

This is where I do my testing before moving packages into Gentoo’s main
[Portage tree](http://sources.gentoo.org/cgi-bin/viewvc.cgi/gentoo-x86/).

While I offer no guarantees, the master branch should be Portage ready.

# Adding to Portage #

It’s easy to gain access to this overlay either through the newer
repos.conf or via layman.

## /etc/portage/repos.conf ##

```ini
[titanofold-dev-overlay]
location = /usr/local/overlay/titanofold-dev-overlay
sync-type = git
sync-uri = https://github.com/titanofold/titanofold-gentoo-x86.git
auto-sync = yes
```

## Layman ##

You can use Layman to access this overlay via Portage. Be sure Layman
is built with the `git` use flag enabled.

```
root # emerge --ask app-portage/layman
```

Create `/etc/layman/overlays/titanofold-dev-overlay.xml` with the following content:

```xml
<?xml version="1.0" ?>

<repositories version="1.0">
  <repo priority="50" quality="experimental" status="unofficial">
    <name>titanofold</name>
    <description>Postgres Experimental, unlimited.</description>
    <homepage>http://github.com/titanofold/</homepage>
    <owner>
      <email>titanofold@gentoo.org</email>
    </owner>
    <source type="git">git://github.com/titanofold/titanofold-gentoo-x86.git</source>
  </repo>
</repositories>
```

Then have Layman add it:

```
root # layman -a titanofold-dev-overlay
```
