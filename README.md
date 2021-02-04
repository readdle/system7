# System 7

System 7 is the Git submodules system for mere mortals.

You use System 7 via a CLI tool named `s7`.

⚠️ Important note: System 7 was originally developed by Mac/iOS development team for their practical needs, thus `s7` is Mac OS only. Please, read [this](Why%20custom%20submodules%20system.md) to understand why we created it.


## Installation

### Homebrew

`brew install readdle/readdle/s7`. To get upgrades later, run `brew upgrade s7`.

After `s7` is installed, we recommend to run `git config --global filter.s7.smudge "s7 bootstrap"`. This is optional, but will save you some extra keystrokes when you get a fresh clone of an s7-driven repo.

### HEAD/Development version install script

Download the file https://github.com/readdle/system7/blob/master/install.sh and run it.

> This command will do the following at your machine:
>  - download System 7 repo to `${HOME}/.system7`
>  - build and install three files to `/usr/local/bin/` – `s7`, `update-s7.sh` and `install-s7.sh`
>  - install `s7 filter` to global Git config

If you want to update `s7` in the future, run `/usr/local/bin/update-s7.sh`.

## Using S7 by Example

Imagine we have a team of developers working on… PDF Viewer application :)
They have versions of their app for Mac and iOS. These projects live in separate repositories. Both use a cross-platform core library, named PDFKit.
Let's see how to set this up with the help of System 7.

> further through this text we will use the term subrepo to talk about submodule. We just like subrepo better than submodule


### Setting things up

Say Alice is setting up the environment.

The first thing to do is to “install” System 7 in the main repo. To do this, Alice calls `s7 init`:

```
[alice @ main-repo] $ s7 init
initialized s7 repo in '/Users/alice/projects/main-repo'
```

`s7 init` installs git-hooks necessary for `s7` to automate all necessary tasks. For example: push subrepo changes when the main repo is pushed; switch subrepos to the proper revision and branches once the main repo is switched between revisions/branches, etc.

The main thing `s7 init` does, is that it creates an `.s7substate` file – the config that will contain the list of subrepos and their state.

> `s7 init` creates and changes some other files too. If you want to learn more, please, read `s7 help init`

Next, let’s add a subrepo!


### Adding a subrepo

```
[alice @ main-repo] $ s7 add Dependencies/PDFKit git@github.com:example/pdfkit.git
Cloning into ‘Dependencies/PDFKit’...
remote: Enumerating objects: 62, done.
remote: Counting objects: 100% (62/62), done.
remote: …
please, don't forget to commit the .s7substate and .gitignore
```

If you look into `.s7substate` now, you will find our first subrepo record there:

```
Dependencies/PDFKit = { git@github.com:example/pdfkit.git, 57e14e93de8af59c29ba021d7a4a0f3bb2700a02, main }
```

You can see that `s7` has recorded:
 - relative path to the subrepo directory
 - the URL to subrepo’s remote
 - the revision of the subrepo
 - and the branch of the subrepo.

If Alice checks `git status` now, she will find that `s7` has created several `.s7*` files (`.s7substate`, etc.) and updated (or created) some Git config files (.gitignore, .gitattributes).
She’s ready to share her work with the team:

```
[alice @ main-repo] $ git add .s7* .gitignore .gitattributes
[alice @ main-repo] $ git commit -m”add PDFKit subrepo”
[alice @ main-repo] $ git push
```

### Starting work on an existing System 7 repo

Alice has done a great work setting up the project. Now her fellow developers can start their work. Let’s see Bob do this.
Bob pulls in the latest changes from Alice:

```
[bob @ main-repo] $ git pull
```

Or, if he wants to get a fresh copy of the main-repo:

```
[bob @ projects] $ git clone git@github.com:example/main-repo.git ...
```

That's it. Bob is ready to go. He should have main-repo and PDFKit subrepo now.

> In some rare cases `s7` might not be able to automatically init System 7 in a repo after clone.
> In such case you would have to run `s7 init` the first time you get a fresh clone of System 7 repo.
> `s7 init` must be run just once in the lifetime of the repository copy – it will install git hooks, and create some 'system' files.


### Day-to-day work

Now, as he has the code, Bob dives in to fix a bug in the PDFKit. He introduces the necessary changes and makes a commit:

```
[bob @ PDFKit] $ git commit -am"fix #1234 – incorrect rendering of a particular pdf file"
```

Bob has made changes in PDFKit. Now he should tell `s7` that the main-repo should now use his new PDFKit commit.

Let's first take a look at what does `s7` think about the state in the main repo:

```
[bob @ main-repo] $ s7 status
Subrepos not staged for commit:
 not rebound commit(s)  Dependencies/PDFKit
```

So, `s7` can see that there some commits in PDFKit. It says they are not "rebound". To make the rest of the team get main-repo looking at his latest commit in PDFKit, Bob has to rebind PDFKit in the main repo:

```
[bob @ main-repo] $ s7 rebind Dependencies/PDFKit
checking subrepo 'Dependencies/PDFKit'... detected an update:
 old state '57e14e93de8af59c29ba021d7a4a0f3bb2700a02' (main)
 new state '445c751e13ab229ff03665e5e046b25b26583742' (main)
```

If he checks the diff, he will see that `.s7substate` file has been updated:

```
[bob @ main-repo] $ git diff
...
- Dependencies/PDFKit = { git@github.com:example/pdfkit.git, 57e14e93de8af59c29ba021d7a4a0f3bb2700a02, main }
+ Dependencies/PDFKit = { git@github.com:example/pdfkit.git, 445c751e13ab229ff03665e5e046b25b26583742, main }
```

Commit. Push: 

```
[bob @ main-repo] $ git commit -am"up PDFKit with the fix to #1234 ..."
[bob @ main-repo] $ git push
```

That's it. If anyone from the team pulls now, they will get the latest version of the main repo and the PDFKit will be updated to the revision just saved by Bob. 

Note that Bob didn't have to go and push PDFKit separately – `s7` took care of that for him. Neither Bob's teammates have to pull PDFKit or do any other manual manipulations – they just run `git pull` and `s7` takes care of the rest.  

### Getting help

This guide has shown just the basics. There're some other commands `s7` can do and of course, there are some options and arguments you can pass to the commands you've seen.

To learn more about `s7` in general, you can run `s7` without any arguments (or `s7 help`). To learn about a particular command, run `s7 help <command>`.

## Contributing
Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors
 - Pavlo Shkrabliuk
 - Nikita Savko
 - Serhii Alpieiev

## License
This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

Hat tip to the Mecurial community for their brilliant product that inspired us.

Special thanks to Nik Savko, Serhii Alpieiev, Andrew Podrugin and Vasyl Tkachuk for all code review suggestions and support.

Thanks to the whole rd2 team who were first to use `s7`. 
