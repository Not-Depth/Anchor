import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { validateMap } from '../src/core/map.js';

export const webRoot = fileURLToPath(new URL('../', import.meta.url));
export const mapPath = fileURLToPath(
  new URL('../../UBAccessNavigator/Resources/demo_map.json', import.meta.url),
);
export async function build() {
  const source = await readFile(mapPath, 'utf8');
  const errors = validateMap(JSON.parse(source));
  if (errors.length) throw new Error(`Demo map validation failed:\n${errors.join('\n')}`);
  const output = resolve(webRoot, 'dist');
  await mkdir(resolve(output, 'data'), { recursive: true });
  for (const name of ['index.html', 'styles.css', 'favicon.svg', 'src']) {
    await cp(resolve(webRoot, name), resolve(output, name), { recursive: true });
  }
  // The native project's map is the source of truth, not a separately edited web copy.
  await writeFile(resolve(output, 'data/demo_map.json'), source);
  return output;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(`Built static web app: ${await build()}`);
}
