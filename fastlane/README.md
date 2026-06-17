fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

Bootstrap UNIQUE (sur Mac) : génère certifs + profils et les pousse dans le repo match

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

Crée la fiche app sur App Store Connect (UNIQUE, via API key)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build et upload sur TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
