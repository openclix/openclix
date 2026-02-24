# Snippet Header Template

Use this header pattern at the top of example snippet files.

## Required Header Content

- What file/class/function this snippet belongs in within a real app
- Whether the code is pseudo-code or references placeholder OpenClix APIs
- Which shared config file this snippet assumes
- Which event names from the scenario it uses

## Header Example

```text
// Example placement: App startup config bootstrap (pseudo-code)
// Adapt to: Your app's dependency injection and notification manager setup.
// Shared config: examples/scenarios/<scenario-slug>/openclix.config.json
// Events used: <entry_event>, <cancel_event>
// Note: OpenClix runtime APIs shown here may be placeholders until the SDK is published.
```
