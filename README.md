# GitSwitcher

A tiny macOS menu bar app to switch between your [GitHub CLI](https://cli.github.com) (`gh`) accounts.

**Website:** <https://marcosesperon.github.io/GitSwitcher/>

It shows the active account in the menu bar and lets you switch to another one with a click — the same as running `gh auth switch --user <account>`, without opening a terminal.

## Why

`gh` already supports several accounts per host and, when it is your git credential helper, it also decides which account `git push` uses. GitSwitcher is just a friendly face for that:

- **No tokens stored.** Accounts come from `gh auth status`; credentials stay in gh's keyring.
- **Always in sync.** Switch from the terminal and the menu bar updates by itself.
- **Small.** One menu, one settings window, no background services.

## Requirements

- macOS 14 Sonoma or later
- [GitHub CLI](https://cli.github.com) with at least one account signed in (`gh auth login`)

## Install

### Homebrew

```sh
brew install --cask marcosesperon/tap/gitswitcher
```

### Manual

Download `GitSwitcher-x.y.z.zip` from [Releases](https://github.com/marcosesperon/GitSwitcher/releases), unzip it and move `GitSwitcher.app` to `/Applications`.

The app is not signed with an Apple Developer ID, so macOS will block it the first time. Either open **System Settings › Privacy & Security** and click **Open Anyway**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/GitSwitcher.app
```

(The Homebrew cask does this for you.)

## Usage

- **Switch account:** click the menu bar item and pick an account. The active one has a checkmark.
- **Add account:** *Settings › Accounts › Add Account…* opens Terminal with `gh auth login`; the new account shows up when you finish.
- **Setup guide:** *Settings › Guide* checks your Mac step by step (gh installed, accounts signed in, git using gh for credentials) and lets you copy each command or run it in Terminal. The menu offers it when something is missing.
- **Settings:**
  - *Open at login*.
  - *Menu bar name*: a short alias per account (e.g. “Work”, “Personal”). Empty means the GitHub username.
  - *Show only the icon in the menu bar*.
  - *Also change the git author when switching* (off by default): sets `user.name` and `user.email` in your global `~/.gitconfig`. Name and email are filled in from your GitHub profile (using your `noreply` address if your email is private) and you can edit them. Leave it off if you set the author per repository or with [`includeIf`](https://git-scm.com/docs/git-config#_conditional_includes).

> **Tip:** to make `git push` follow the active account, let gh handle git credentials: `gh auth setup-git`.

## Build from source

```sh
brew install xcodegen
xcodegen generate
open GitSwitcher.xcodeproj
```

Or from the command line:

```sh
xcodebuild -project GitSwitcher.xcodeproj -scheme GitSwitcher build
xcodebuild -project GitSwitcher.xcodeproj -scheme GitSwitcher test
```

The Xcode project is generated from `project.yml` and is not committed.

## Languages

English and Spanish. Translations live in `GitSwitcher/Resources/Localizable.xcstrings`; pull requests with new languages are welcome.

## License

[MIT](LICENSE)
