export const WIDTH = 32, HEIGHT = 16, SEASONS = 12;
export const BASE = 50;
export const Prediction = Object.freeze({more: 'more', fewer: 'fewer', equal: 'equal'});

export function initial(seed) {
  let state = seed >>> 0;
  function random() {
    state = (Math.imul(1664525, state) + 1013904223) >>> 0;
    return state / 4294967296;
  }
  return Array.from({length: WIDTH * HEIGHT}, () => ({
    kelp: 0.1 + 0.85 * random(), grazers: random() < 0.16 ? 0.5 : 0
  }));
}

export function response(kelp, values) {
  const half = kelp < 0.5 ? 0 : 1;
  return (values[half] + (values[half + 1] - values[half]) * (kelp * 2 - half)) / 100;
}

// Densities mix across four wrapped neighbors before local growth and consumption.
export function step(world, values) {
  return world.map(({kelp, grazers}, i) => {
    const x = i % WIDTH, y = Math.floor(i / WIDTH);
    const neighbors = [y * WIDTH + (x + 1) % WIDTH, y * WIDTH + (x + WIDTH - 1) % WIDTH,
      ((y + 1) % HEIGHT) * WIDTH + x, ((y + HEIGHT - 1) % HEIGHT) * WIDTH + x];
    const incoming = neighbors.reduce((sum, n) => sum + world[n].grazers, 0) / 4;
    const density = 0.8 * grazers + 0.2 * incoming;
    const consumed = Math.min(kelp, density * response(kelp, values) * 0.85);
    return {
      kelp: kelp + 0.24 * kelp * (1 - kelp) - consumed,
      grazers: Math.min(1, density * 0.82 + consumed * 0.58)
    };
  });
}

export function cover(world, species) {
  return 100 * world.reduce((sum, cell) => sum + cell[species], 0) / world.length;
}

export function run(seed, rule) {
  const seasons = [initial(seed)];
  for (let i = 0; i < SEASONS; i++) seasons.push(step(seasons[i], rule));
  return seasons;
}

export function outcome(base, branch) {
  const difference = cover(branch, 'grazers') - cover(base, 'grazers');
  return difference > 0 ? Prediction.more : difference < 0 ? Prediction.fewer : Prediction.equal;
}
