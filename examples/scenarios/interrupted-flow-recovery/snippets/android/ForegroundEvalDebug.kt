// Example placement: ProcessLifecycleOwner foreground callback for re-evaluation + debug (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/interrupted-flow-recovery/openclix.config.json
// Events used: handleAppForeground, getSnapshot, explain
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

fun debugInterruptedFlowRecoveryOnForeground(openClix: OpenClixManagerLike) {
    openClix.handleAppForeground()
    val snapshot = openClix.getSnapshot()
    println("OpenClix snapshot: $snapshot")

    val trace = openClix.explain(
        campaignId = "interrupted-flow-recovery",
        messageId = "resume-flow-reminder"
    )
    println("OpenClix explain trace: $trace")
}
