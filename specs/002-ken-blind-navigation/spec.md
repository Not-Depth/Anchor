# Earlier obstacle warnings and spoken landmark navigation

Ken confirmed on November 20 that the map task now means a blind-first guide for the fictional Demo Hall route from North Plaza to Room 201. This work supersedes the November 7 wheelchair draft. The base is the team's floor-detection stack at `d9c49a42`, including the blind-navigation rebrand and recorded voice support.

## Requirements

- **N1. Timely evaluation.** Native Nearby evaluates each fresh depth reading on arrival. After sustained signal loss, a fresh near reading produces the warning first. A far recovery announces restored depth. A timer still monitors stale or absent readings. Threshold chatter and repeated alerts stay bounded.
- **N2. Distance and message.** New installations default to 3 m. Existing saved choices are preserved. Audio alerts use “Warning, objects ahead at [measured distance] meters.” with one decimal. The native phrase also belongs to the voice-clip catalog. Use the established fallback for unavailable clips and the existing VoiceOver delivery.
- **N3. Platform and sensing boundaries.** Native Nearby reports depth in the forward camera view. The browser companion simulates the same alert state and never uses LiDAR. Treat end-to-end speech timing and sensor behavior as unverified until tested on an iPhone. Ken has no new decision to add a movement command.
- **G1. Guide format and data.** Deliver an offline HTML guide and tagged PDF with the normal two-floor North Plaza to Room 201 route. Include every authored instruction, nonvisual arrival cue and confirmation label in the app's order. Preserve the fictional label, simulated lengths and unrecorded stairway length.
- **G2. Control and accessibility.** The first focused guidance step identifies the fictional route and destination. Travel advances by explicit confirmation. The optional iPhone floor check provides feedback while a floor-changing step is active. The browser has no floor check. Include the behavior when Stairwell A or its elevator alternative is unavailable.

## Implementation and review

- N1–N3 use the existing depth stream, speech service and saved settings. The web simulation uses the matching warning and recovery rules with a simulation label. The phrase catalog covers the actual one-decimal distances the policy can speak, including the range allowed by hysteresis.
- G1 follows all eight guidance screens, including seven manual confirmations and the final arrival. Verified against the shared planner and its closure cases. The PDF follows HTML reading order.
- G2 adds the fictional route and destination to the first focused instruction on iPhone and web. The browser walkthrough checks keyboard focus and accessible names along with manual progression.

The [handoff](handoff.md) records what to verify on iPhone and what to review with Johnny.
