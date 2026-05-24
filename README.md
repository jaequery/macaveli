# Macaveli

> Sweet window management and screen recording for macOS

## Installation

* Download the [latest release on Github](https://github.com/jaequery/Macaveli/releases)
* Clone it and build it yourself

## Features

* Launch at login
* Hide menubar icon
* Focus on window
* Smart resizing with quadrants
* Screen recording with hotkey toggle, MP4/GIF export

## Contributing

You can either use Xcode or build it directly from the command line:

### Build and run from the command line

```bash
make run
```

### Accessibility permissions running locally

Make sure you don't have Macaveli running already. If you have 2 versions of Macaveli, only one will get
Accessibility permissions. To fix it:

* Quit all Macaveli instances
* Remove Macaveli from the System Preferences > Security & Privacy > Accessibility
* Run the app you want to test
* Enable Accessibility permissions

I'm open to PRs and requests.
