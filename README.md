# System 7

System 7 is the Git submodules system for mere mortals.

You use System 7 via a CLI tool named `s7`.

Read [this](Why%20custom%20submodules%20system.md) to understand why we created this.


## Installation

Download the file https://github.com/readdle/system7/blob/master/install.sh and run it.
It will clone system7 repo to “${HOME}/.system7”, build `s7` and install to `/usr/local/bin/`.

To update s7, run `/usr/local/bin/update-s7.sh`.


## Using S7 by Example

Imagine we have a team of developers working on… PDF Viewer application :)
They have versions of their app for Mac and iOS. These projects live in separate repositories. Both use a cross-platform core library, named PDFKit.
Let's see how to set this up with the help of System 7.

> further through this text we will use the term subrepo to talk about submodule. We just like subrepo better than submodule


### Set up

Say Alice is setting up the environment.

First thing to do is to “install” s7 into the main repo. To do this, Alice calls `s7 init`:

```
[alice @ main-repo] $ s7 init
initialized s7 repo in '/Users/alice/projects/main-repo'
```

`s7 init` installs git-hooks necessary for s7 to automate all necessary tasks. For example: push subrepo changes when the main repo is pushed; switch subrepos to the proper revision and branches once the main repo is switched between revisions/branches, etc.

The main thing `s7 init` does, is that it creates an `.s7substate` file – the config that will contain the list of subrepos and their state.

> `s7 init` creates and changes some other files too. If you want to learn more, please, read `s7 help init`

Next, let’s add a subrepo!


### Add a subrepo

```
[alice @ main-repo] $ s7 add Dependencies/PDFKit git@github.com:example/pdfkit.git
Cloning into ‘Dependencies/PDFKit’...
remote: Enumerating objects: 62, done.
remote: Counting objects: 100% (62/62), done.
remote: …
please, don't forget to commit the .s7substate and .gitignore
```

If you look into .s7substate now, you will find our first subrepo record there:

```
Dependencies/PDFKit = { git@github.com:example/pdfkit.git, 57e14e93de8af59c29ba021d7a4a0f3bb2700a02, master }
```

You can see that `s7` has recorded:
  - relative path to the subrepo directory
  - the URL to subrepo’s remote
  - the revision of the subrepo
  - and the branch of the subrepo.

If Alice checks `git status` now, she will find that `s7` has created serveral .s7* files (.s7substate, etc.) and updated (or created) some Git config files (.gitignore, .gitattributes).
She’s ready to share her work with the team:

```
[alice @ main-repo] $ git add .s7* .gitignore .gitattributes
[alice @ main-repo] $ git commit -m”add PDFKit subrepo”
[alice @ main-repo] $ git push
```

### Starting work on an existing s7 repo

Alice has done the great work setting up the project. Now her fellow developers can start their work. Let’s see Bob do this.
Bob pulls in the latest changes from Alice.

```
[bob @ main-repo] $ git pull
```

Or, if he wants to get a fresh copy of the main-repo:

```
[bob @ projects] $ git clone git@github.com:example/main-repo.git ...
```

That's it. Bob is ready to go. He should have main-repo and PDFKit subrepo now.

> In some rare cases `s7` might not be able to automatically init s7 in a repo after clone.
> In such case you would have to run `s7 init` the first time you get a fresh clone of s7 repo.
> `s7 init` must be run just once in the lifetime of the repository copy – it will install git hooks, and create some 'system' files.


### status

### rebind

### push/pull

### merge

### Getting help

`s7 help` and `s7 help <command>`


# Здесь рыбу заворачивали


Adding subrepos
To add a subrepo, use `s7 add` command.
`s7 add [--stage] PATH [URL [BRANCH]]`
The only required argument for `s7 add` is the path where subrepo will live.
If you’ve already cloned the subrepo to that PATH, you can run just `s7 add <path>` and s7 will deduce URL and BRANCH from the subrepo Git status.
If you haven’t clone subrepo, then you must pass at least <path> and <url> parameters. s7 will clone subrepo from <url> to the <path>.
`s7 add` registers the new subrepo in `.s7substate` and `.gitignore`. These two files must be committed to share the new subrepo and its recorded state with fellow developers. `--stage` option may be used to automatically prepare these file commit with the next `git commit`.

Example:

Bob add a new subrepo:
	[main-repo] $ s7 add --stage /Dependencies/YAMLParser git@.../yaml-parser.git
	[main-repo] $ git commit -m”add yaml parser subrepo”

Alice gets Bob’s code that uses the new subrepo:
	[main-repo] $ git pull

that’s it! No need to run any special commands. s7 will checkout subrepos automatically. (NOTE: there arecases when s7 cannot do this automatically, we’ll discuss them later).


Borista suggests to draw diagrams that explain submodules to the newbys

