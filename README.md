# System 7

System 7 is the Git submodules system for mere mortals.

System 7 is a CLI tool named `s7`. TODO: tell about hooks here?

## Installation

Download the file https://github.com/readdle/system7/blob/master/bootstrap.sh and run it.
It will clone system7 repo to “${HOME}/.system7”, build `s7` and install to `/usr/local/bin/`.

To update s7, run `/usr/local/bin/update-s7.sh`.

## Using S7 by Example

Imagine we have a team of developers working on… PDF Viewer application :)
They have versions of their app for Mac and iOS. These projects live in separate repositories. Both projects use the cross-platform core library called PDFKit.
Setting up the project

Say Alice is setting up the environment.

First thing to do is to “install” s7 into the main repo. To do this, Alice calls `s7 init`:

```
[alice @ main-repo] $ s7 init
initialized s7 repo in '/Users/alice/projects/main-repo'
```

`s7 init` installs git-hooks necessary for s7 to automate all necessary tasks. For example: push subrepo changes when the main repo is pushed; switch subrepos to the proper revision and branches once the main repo is switched between revisions/branches, etc.

The main thing `s7 init` does, is that it creates an `.s7substate` file – the config that will contain the list of subrepos and their state.

(`s7 init` creates and changes some other files too. If you want to read more about this, please, checkout `s7 help init`)

Next, let’s add the subrepo!

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

Besides the directory where subrepo lives and the URL to subrepo’s remote, you can see that this file saves the exact revision and the branch of a subrepo.

If Alice checks `git status` now, she will find that she has three changed files: .s7substate, .gitignore and .gitattributes (you can check out `s7 help init` for more info on each file). She’s ready to share her work with the team:

```
[alice @ main-repo] $ git add .s7substate .gitignore .gitattributes
[alice @ main-repo] $ git commit -m”add PDFKit subrepo”
[alice @ main-repo] $ git push
```

## Starting work on an existing s7 repo

Alice has done great work on setting up the project. Now her fellow developers can start their work on the actual project. Let’s see Bob do this. Bob pulls in the latest changes from Alice. Now he should run `s7 init` to let s7 take care of subrepos in his main repository.

```
[bob @ main-repo] $ git pull
remote: Enumerating objects: 7, done.
remote: Counting objects: 100% (7/7), done.
…

[bob @ main-repo] $ s7 init
reinitialized s7 repo in '/Users/bob/projects/main-repo'
cloning subrepo 'Dependencies/PDFKit' from 'git@github.com:example/pdfkit.git'
...
```

`s7 init` must be run just once in the lifetime of the repository clone. Meaning, Bob won’t have to call `s7 init` anymore in '/Users/bob/projects/main-repo' – it’s all set.

`s7 init` has performed mostly the same job it did in Alice’s repo – installed git hooks, created some system files. But in Bob’s case `.s7substate` file has existed, thus `init` has automatically cloned PDFKit subrepo and checked it out to the state that Alice has recorded in the config.




# Здесь рыбу заворачивали


## Getting help

`s7 help` and `s7 help <command>`

Init

To do its work, s7 uses Git hooks, patches .gitattributes and creates some configuration files. To install all these, once in the lifetime of a repository clone, run `s7 init` in the root directory of the repository.

For example:

Alice is setting up s7 for their team. She runs:
	[main-repo] $ s7 init
	initialized s7 repo in '/Users/alice/projects/main-repo'
[main-repo] $ git status
On branch master
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	new file:   .gitattributes
	new file:   .gitignore
	new file:   .s7substate
	[main-repo] $ git add .
	[main-repo] $ git commit -m”set up s7”
	[main-repo] $ s7 add ...

Bob has cloned the main-repo after Alice had set up s7 in it:
	[projects] $ git clone git@... main-repo
	[projects] $ cd main-repo
	[main-repo] $ s7 init
	reinitialized s7 repo in '/Users/bob/projects/main-repo'
	checking out …

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


## Why custom subrepos system?

We are the people of Mercurial. We would happily continue using Mercurial if Bitbucket didn’t “sunset” its support. Unfortunately, Hg community doesn’t have any alternative hosting with the proper code review support that we need, thus we were forced to migrate to GitHub (and Git of course).

As Hg users, we got used to the seamless and painless work with subrepos. Git world has the following analogs to Hg subrepos:
Git submodules. Also known as “sobmodules”. We had had experience with this beast and had no desire to use it again.
Detached HEADs. No clue about the branch that was used by the developer who checked in the revision. No thank you. (yeah-yeah, there’s an alternative - use the latest version of a branch, but that doesn’t always work well with our set of subrepos).
Ton of manual work -- subrepos are not checked out automatically.
And the cherry on top of this pie -- an awful CLI interface. Constant juggling with update/init/recursive --omg-what-the-hell-does-this-key-mean. And the worst thing is -- if you don’t update submodules, there’s no hint about that -- project may even build. Do you know how to get the latest version of subrepos in Hg -- you just checkout the necessary revision/branch of the main repository.
Git-subrepos and git-subtree. We don’t have experience with these two, but the fact that both of them keep the full history of subrepos’ files in the main repository seems… odd… very odd…

For those of you who may not know how subrepos work in Hg. There’re two files in the main repository -- .hgsub and .hgsubstate. You add the subrepo by adding a line to the .hgsub, like this:
  Dependencies/RDPDFKit = ssh://hg@bitbucket.org/readdle/rdpdfkit
The key is the path where subrepo will live relative to the main repository root. The value is the URL where subrepo can be cloned.
When you make changes to the subrepo and want to link the main repository to the revision of a subrepo, you just make a commit in the main repository -- it records all changed subrepos to the .hgsubstate. For example:
  dec5aae9e22cd0a07cfba3ba02fdb0e1f243e07e Dependencies/RDPDFKit
As each commit is bound to a branch in Hg, this also implies the branch information.
When you checkout any commit of the main repository, Hg takes care of checking out all subrepos to the state saved in .hgsubstate.

An ideal subrepositories system we would like to use, meets the following requirements:
seamless checkout of subrepos when a revision/branch of the main repo is checked out
human-friendly CLI interface
no detached HEADs. The system we want must remember the branch where the subrepo commit belongs.

Inspired by the Hg subrepos, we came up with the following:
file in the main repo that keeps track of subrepos. The only difference is that we made one file that serves both purposes -- keeps track of subrepos and revisions/branches of subrepos. The file is named `.s7substate`
explicit CLI command to save the state of a subrepo into `.s7substate`. `s7 rebind`
