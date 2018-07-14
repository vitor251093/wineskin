# Wineskin

[![Build Status](https://travis-ci.org/vitor251093/wineskin.svg?branch=master)](https://travis-ci.org/vitor251093/wineskin)

**Wineskin** is a user-friendly tool used to make ports of Microsoft Windows software to Apple's macOS/Mac OS X.

## How Does It Work?

As described in the [original Wineskin's website](http://wineskin.urgesoftware.com/):

> The ports are in the form of normal macOS application bundle wrappers.
> It works like a wrapper around the Windows software, and you can share just the wrappers if you choose.
> 
> Make ports/wrappers to share with others, make ports of your own open source, free, or commercial software, or just make a port for yourself!
> Why install and use Windows if you don’t need to?

Wineskin relies on [WINE](www.winehq.org) ("WINE Is Not an Emulator") under the hood:

> Instead of simulating internal Windows logic like a virtual machine or emulator,
> Wine translates Windows API calls into POSIX calls on-the-fly,
> eliminating the performance and memory penalties of other methods
> and allowing you to cleanly integrate Windows applications into your desktop.

## Quick Start

Install [Carthage](https://github.com/Carthage/Carthage) via [Homebrew](https://brew.sh/) to manage the build dependencies:

```bash
$ brew install carthage
```

Clone the repository and build the dependencies:

```bash
$ git clone https://github.com/Gcenx/wineskin.git
$ cd wineskin/
$ carthage update
```

Open `Wineskin.xcworkspace` in Xcode and build:

```bash
$ open Wineskin.xcworkspace
```

Or build via the command line:

```bash
$ xcodebuild -workspace Wineskin.xcworkspace -scheme Wineskin build
$ xcodebuild -workspace Wineskin.xcworkspace -scheme "Wineskin Winery" build
$ xcodebuild -workspace Wineskin.xcworkspace -scheme WineskinLauncher build
```

## Changes from the original project

As you may have already noticed, this is not the [original Wineskin repository](https://sourceforge.net/p/wineskin/code/ci/master/tree/).
This repository counts with changes to make Wineskin more stable and its source easier to maintain.
Considering this, lots of changes were made in WineskinApp and WineskinLauncher, and now both of them use [ObjectiveC_Extension](https://github.com/vitor251093/ObjectiveC_Extension) and some new classes to perform most of their tasks. 

### Changes in the Wineskin App (WineskinApp)

- The Resolution property in Info.plist should never get corrupted (*(null)x24sleep0*);
- The *Auto-detect GPU* feature should never cause malfunction in the port;
- The *Auto-detect GPU* feature should have a much bigger accuracy and detect the memory size of integrated video cards as well;
- Enabling *Mac Driver* and *Decorate window* checkboxes should not corrupt the wrapper registry;
- The *Retina Mode* can be enabled from the Screen Options window;
- *Kill Wineskin Processes* should kill ALL Wineskin processes.
- Icons can be extracted directly from exe files;
- Images (not .icns files) should also be accepted has wrapper icons;
- LNK files should be able to be selected as a port's run path, so Wineskin can extract the path and flags from it;
- Winetricks installation can be silent (with no windows) so it's much faster;
- The first *Advanced* tab (*Configuration*) should be much more simple in the first section:
    - The *Windows EXE* should use Wineskin syntax, including the drive and the flags, (eg. *"C:/Program Files/temp.exe" --run*) instead of using a macOS reference path (eg. */Program Files/temp.exe*) and the flag apart (eg. *--run*).

### Changes in the Master Wrapper (WineskinLauncher)

- Many fixes when dealing with newest engines.
- WineskinX11 dropped.

### Roadmap of desired changes in the Master Wrapper (WineskinLauncher)

- A different Master Wrapper for macOS 10.6 and 10.7;

## Licensing

The license is kept the same as the original material as LGPL 2.1.
You can find more details in the [LICENSE](LICENSE) file.

## Credits

Special credits for this version go to doh123, for creating the original Wineskin
[[website](http://wineskin.urgesoftware.com/)] [[code](https://sourceforge.net/projects/wineskin/)].
