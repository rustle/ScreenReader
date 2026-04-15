# ScreenReader

The building blocks of a screen reader for macOS in Swift

## Usage

### Accessibility trust

The process must be granted Accessibility permission before any AX API calls are made. `AX.isTrusted(promptIfNeeded:)` checks the current trust state and can prompt the user via System Settings.

```swift
import AX

guard AX.isTrusted(promptIfNeeded: true) else {
    exit(1)
}
```

`ScreenReader.confirmTrust()` wraps this and exits the process if trust is not granted.

Code signing your project seems to make a noticeable difference when iterating on a project. Without codesigning you will constantly need to toggle trust on and off manually to clear out cobwebs.

### Dependency Injection

`ScreenReader` is configured entirely through `Dependencies`, which holds two factory closures called at startup.

```swift
import ScreenReader

let dependencies = Dependencies(
    screenReaderDependenciesFactory: {
        ScreenReaderDependencies(
            isTrusted: { AX.isTrusted(promptIfNeeded: $0) },
            runningApplicationsFactory: { WorkspaceRunningApplications() },
            outputContextsFactory: { [SpeechInProcess()] }
        )
    },
    serverProviderDependenciesFactory: {
        ServerProviderDependencies(
            inclusionListFactory: { [] },   // empty = allow all
            exclusionListFactory: {
                // exclude processes that should never be observed
                ["com.apple.VoiceOver"]
            }
        )
    }
)
```

**`outputContextsFactory`** returns the output pipeline. Each `OutputContext` receives every `Output.Job` in order. The built-in contexts are:

| Type | Description |
|---|---|
| `SpeechInProcess` | Speech via `NSSpeechSynthesizer` on a dedicated thread |
| `SpeechDaemon` | Speech via `AVSpeechSynthesizer` (system speech daemon, XPC) |
| `Braille` | Stub — future work to drive a braille display will live here |
| `Text` | Stub — future work to offer a caption panel will live here |

In the bright and wonderful future where we've built braille support, you'd supply multiple contexts to fan output to speech and braille simultaneously, for example.

**`inclusionListFactory`** and **`exclusionListFactory`** take sets of bundle identifiers. If the inclusion list is non-empty, only those applications are observed. The exclusion list is always applied. The process's own bundle identifier is excluded automatically.

### Start

```swift
let screenReader = ScreenReader(dependencies: dependencies)
screenReader.confirmTrust()

Task {
    do {
        try await screenReader.start()
    } catch {
        print("Failed to start: \(error)")
        exit(1)
    }
}
```

`start()` subscribes to the stream of running applications from `RunningApplications` and spins up a `Server` for each one. Each `Server` owns an `Application` controller that registers AX observers, builds the controller hierarchy, and drives output as focus and content change.

Call `stop()` to cancel all observation and tear down every active `Server`.

### Application lifecycle

`ScreenReader` manages application lifetime automatically. When a new application appears in the running applications stream, a `Server` is created and started. When the application exits, the `Server` is stopped and its resources are released. No manual management of per-application state is required.

### 5. Running as a background agent

Screen readers typically run without a dock icon or menu bar presence. Set the activation policy before starting:

```swift
NSApp.setActivationPolicy(.prohibited)
```

The `Info.plist` should include `LSUIElement = YES`. Accessibility permission is granted by the user through System Settings → Privacy & Security → Accessibility.

## Customization and Extensibility

This project, despite being an ongoing research project since 2018 or so, still has a ways to go before it can robustly support customization by library consumers.

That being said I've given it a great deal of thought.

* How we build out hierarchy needs to at the very least be configurable if not entirely replacable.
* How we build and keep the list of running apps up to date.
* A custom OutputContext is already an option, but needs lots of work so making your own context doesn't mean starting from scratch.
* I haven't done much on navigation yet, but when it's time for that it will need to come in via DI like OutputContext so it can be replaced. Also like OutputContext customization shouldn't mean building from scratch, wherever possible.

It's going to be a minute, but an important use case for me is supporting `Element` and/or `Controller` implementations that use a DistributedActor and XPC to allow untrusted (aka user provided) scripts to load in a sandboxed environment to perform per app accessibility customization. This is the use case I started the whole project to build towards and I won't consider it done until that's working. I built a proof of concept for this before I built out any of this infrastructure. It was fun, but very much a toy. I needed Swift to grow up, but the basic plan that we'd get a coroutine/actor model was announced so I've been building a little at a time since then.

## RunLoopExecutor and per-application threading model

Each application monitored by ScreenReader gets a dedicated `RunLoopExecutor` — a thread whose `CFRunLoop` is the sole executor for all work relating to that application. `AXObserver` callbacks, accessibility IPC reads, controller actors (`Application`, `ControllerHierarchy`, `TextArea`, etc.), and the `ApplicationObserver` all run on this single thread.

The accessibility APIs are built on top of Mach IPC. The applications being observed service all of that IPC on their main thread. If ScreenReader were to issue concurrent attribute reads from multiple threads, those requests would pile up on the remote application's main thread and contend with each other, degrading performance for the user and for the observed application. Serialising all work for a given application onto one thread eliminates that contention.

`AXObserver` itself is a `CFRunLoopSource` and must be scheduled on a `CFRunLoop`. Scheduling all observers and doing all IPC on the same `CFRunLoop` means callback delivery and attribute reads are naturally serialised without any additional locking.

### Why not Swift concurrency's cooperative thread pool

Swift's cooperative executor distributes work across a pool of threads. Pinning accessibility work to a specific `CFRunLoop` thread is incompatible with that model: `CFRunLoopSource` callbacks fire on the thread the run loop is running on, and there is no guarantee the cooperative pool will reuse the same thread. A custom `SerialExecutor` ends up working pretty well.

### Sharing the executor

The same `RunLoopExecutor` instance is passed through `Application`, `ControllerHierarchy`, and each controller actor. All of those actors adopt it as their `unownedExecutor`, so they share one underlying thread. This means actor hops between them are cheap (no actual thread switch), and IPC issued from any of them is automatically serialised.

Swift 6.2's region-based isolation analysis (`#SendingRisksDataRace`) flags passing the executor across actor init boundaries even though `RunLoopExecutor` is `@unchecked Sendable` so we're stuck with a `sending` annotation until I have time to make `RunLoopExecutor` properly `Sendable`.

### Future work

* Heartbeat and IPC timeout tracking: Accessibility IPC to an unresponsive application blocks the run loop thread for the duration of the system timeout. A watchdog timer running off the run loop or a sliding window tracking how often `Element` calls are timing out could detect stalls and surface them — by temporarily suspending observation of and IPC calls to that application.

## License

ScreenReader is released under an Apache license. See the LICENSE file for more information
