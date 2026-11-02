export function guidanceSteps(route) {
  return [
    {
      instruction: `Start at ${route.start.name}.`,
      cue: route.start.arrivalCue,
      confirm: `I'm at ${route.start.name}`,
      landmarkID: route.start.id,
    },
    ...route.legs.map((leg) => ({
      instruction: leg.instruction,
      cue: leg.to.arrivalCue,
      confirm: `I've reached ${leg.to.name}`,
      landmarkID: leg.to.id,
      connection: leg.connection,
    })),
    {
      instruction: `You have arrived at ${route.destination.name}.`,
      cue: '',
      confirm: null,
      landmarkID: route.destination.id,
    },
  ];
}

export function moveStep(index, direction, steps) {
  return Math.max(0, Math.min(steps.length - 1, index + direction));
}
