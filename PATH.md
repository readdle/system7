# Journey HOME

`s7` can be installed in two ways: using install scripts for Readdle internal use and using Homebrew. This means that there's no single known path where the `s7` binary may get installed.

`s7` uses Git hooks to automate the work with subrepos as much as possible. Ideally, if the end user doesn't have to rebind subrepos, they will not have to launch `s7` by hand at all. For Git hooks to work properly, `s7` must be visible from the context where a hook gets launched. There are two such contexts: CLI and GUI.

Historically, all Readdle internal tools are installed to "$HOME/bin". I didn't know any reasons for that and just followed the tradition. I'm a console person, so I tested `s7` in terminal and everything worked smoothly.

From day one it became obvious that the majority of people prefer GUI tools to work with Git. My first reaction was,– "Then add "$HOME/bin" to the PATH?". Turned out that adding something to the PATH for GUI apps is not an easy task at the modern macOS.

> If you were curious, the default PATH for GUI apps looks like this `/usr/bin:/bin:/usr/sbin:/sbin`. Many apps add some stuff to the `PATH` once they launch, for example, `SourceTree` adds the paths to its custom `git-lfs`, `Xcode` adds `SDK/bin`, etc.

`.bash_profile`/`.zshrc` – don't work for GUI apps\*. I was sometimes fooled by my love to launch Xcode using `xed`, or SourceTree using `stree`. GUI apps started from Finder, Dock, Spotlight, or by launch services don't consult shell profiles.

`/etc/paths`, `/etc/paths.d/*` – I had a vague hope this would work. No, it won't. This one IS used by Terminal, but GUI doesn't consult it.

`launchctl setenv PATH VALUE` – doesn't work particularly for the `PATH` variable. Haven't found it in the documentation, but my tests tell so. It works for custom variables, like `MY_TEST` – `launchctl setenv MY_TEST VALUE` works, `PATH` – nah. Doesn't work even if set from `~/Library/LaunchAgents/*.plist`. (NOTE: Haven't checked this, but people at Stack Overflow write that LaunchAgents-set variables don't work for apps started by reopening the last open windows and for Preferences > Users & Groups > Login Items. Might be worth checking if we need a different environment variable someday).

The only way, my teammates found, that works is to run `sudo launchctl config user path VALUE`. I didn't want users to trust me with superuser rights (even just for the installation) to work with `s7` (considering that `sudo <something>` would be hidden in the guts of an install script/brew formula).

I turned my sight to the standard directories. `/usr/local/bin` in particular caught my attention. `Xcode` offers to install CLI tools to `/usr/local/bin` by default. As of that time, Homebrew used to install to `/usr/local/bin` by default. That, at least, offered a unification of the install path for our internal scripts and Homebrew. The default `/etc/paths` contains `/usr/local/bin`, so there was no need to modify the user's `PATH` to make work from Terminal possible. The use of `/usr/local/bin` didn't free me from the need to do something about `PATH` for GUI apps though.

Based on our experience, not all people keep an eye on internal utils updates (even though we send an email to the devlist on every update). People forget, they are busy, they don't love CLI, and don't want to bother. Depending on the utility that resulted in different issues. For example, a bug in the localization tool that had been fixed months ago would pop up in our project, 'cause someone didn't bother to update the necessary tool. To remove the human factor, we automated the necessary tools install and update process. We have the Run Phase in our Xcode project that updates our internal tools if necessary. I wanted to keep `s7` up-to-date on every engineer's machine. For Run Phase to be able to silently install updates, the installation directory must be writable for usual non-admin/non-sudo user. And `/usr/local/bin` had exactly such rights*.

Back to the original problem of GUI apps. `s7` is "used" by GUI apps indirectly through Git hooks, so I came up with a solution: we settle `s7` in the `/usr/local/bin` and hardcode `/usr/local/bin/s7` in all `s7` hooks. GUI apps won't need to look up the PATH, for the day-to-day use in CLI there would be no need to modify the user's `PATH`. Win-win! :tada: 

Boy, was that the wrong path.

`s7` was written in the time when few people had M1 Macs. We knew that `/usr/local/bin` didn't exist on M1. But the reason was not clear. Once M1 emerged, Homebrew started using `/opt/homebrew/` for ARM, and `/usr/local/bin` for Intel architecture. Well, that made sense for them 🤷‍♂️. But for us, with our hardcoded `/usr/local/bin` in Git hooks... Well, we build `s7` on every user's machine, so there was no need to separate architectures. By the time we got the first M1 Macs we didn't want to change our decision to hardcode `/usr/local/bin` in Git hooks: that would mean migration, the need for a new PATH, or some dynamic search of `s7`. We didn't want all that hassle, so we proclaimed that everyone who has M1 must do the following:

```
 sudo mkdir -p /usr/local/bin
 sudo chown "$USER" /usr/local/bin
```

That mimicked the rights on `/usr/local/bin` that we had on Intel machines. 

Three years passed with the decision to live in `/urs/local/bin`.

Until I stumbled on this [article](https://applehelpwriter.com/2018/03/21/how-homebrew-invites-users-to-get-pwned/).

It made me sweat.

With my own hands I made the team of about 30 engineers vulnerable to sudo spoofing.

And then the dam had broken... I have a Homebrew version of Git on my machine. To use it, I **prepended** `/opt/homebrew/bin` to my `PATH`. And what are the rights of `/opt/homebrew/bin`? owner = $USER, 775. Well, alright, I did this with my own hands again. I decided to check what the internet has to say about it. Sure enough, you will find the same answer,– "prepend. the. `/opt/homebrew/bin`. to. your. PATH.". Even worse. Take a look at what `/opt/homebrew/bin/brew shellenv` does – it... prepends `/opt/homebrew/bin` to your PATH.

Sure enough, when I decided to use `/usr/local/bin`, this directory permissions were modified by `Homebrew`. Of course, I'm to blame too. After reading the article above every piece of puzzle I knew before just made the whole picture.

Our predecessors who chose "$HOME/bin" must have known something. We are moving back HOME.

Not to do any migrations we decided that users must make a link to `"$HOME/bin/s7"` in their `/usr/local/bin/s7`: `/usr/bin/sudo ln -s "$HOME/bin/s7" /usr/local/bin/s7`. If someday we get some real external users, who install `s7` via Homebrew, then they will have to make such a link too. 
