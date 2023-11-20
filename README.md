# ScreenReader

The building blocks of a screen reader for macOS in Swift

## License

ScreenReader is released under an Apache license. See the LICENSE file for more information

## Getting Started

* Setting up a `ScreenReader` instance.
    * Dependencies
        * Screen Reader Dependencies
            * Trust
            * Running Applications
        * Server Dependencies
            * Applications to include
            * Applications to ignore

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
