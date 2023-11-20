# ScreenReader

The building blocks of a screen reader for macOS in Swift

## License

ScreenReader is released under an Apache license. See the LICENSE file for more information

## Getting Started

* Setting up a `ScreenReader` instance.
    * Dependencies
        * [Screen Reader Dependencies](#screen-reader-dependencies)
            * [Trust](#trust)
            * [Running Applications](#running-applications)
        * [Server Dependencies](#server-dependencies)
            * [Applications to include](#applications-to-include)
            * [Applications to ignore](#application-to-ignore)

```
let dependencies = Dependencies(
        screenReaderDependenciesFactory: {
            ScreenReaderDependencies(
                isTrusted: AX.isTrusted(promptIfNeeded:),
                runningApplicationsFactory: {
                    WorkspaceRunningApplications()
                }
            )
        },
        serverProviderDependenciesFactory: {
            ServerProviderDependencies(
                inclusionListFactory: {
                    []
                },
                exclusionListFactory: {
                    [
                        "com.apple.voiceover",
                        "com.apple.webkit.databases",
                        "com.apple.webkit.networking",
                        "com.google.Keystone.Agent",
                        "com.apple.accessibility.axvisualsupportagent",
                    ]
                }
            )
        }
    )
}
let screenReader = ScreenReader(dependencies: dependencies)
```

### Screen Reader Dependencies

Dependencies for configuring your `ScreenReader` instance.

#### Trust

Perform any operations needed for your elements to have access to the accessibility API they depend on. `AX.isTrusted(promptIfNeeded:)` will provide this if your `ScreenReader` instance operates entirely against `SystemElement`s.

#### Running Applications

### Server Dependencies

Dependencies for configuring your `ServerProvider` instance.

#### Applications to include

#### Applications to ignore

## Types

### Server

### Controllers

### Output

### Hierarchy
