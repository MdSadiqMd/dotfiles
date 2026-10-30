# Build a 3D scene

A 3D scene is a `<code>` graphic drawn with react-three-fiber: Cardboard renders it natively, every frame is exact, and
the human can still change the geometry, lighting, camera and timing afterwards.

## three.js or generated video

Choose by what the shot needs; the two also combine (a generated plate under a three.js title or graphic).

- **three.js fits** titles and logos set into a 3D scene; products, devices and diagrams whose shape must be exact;
  stylized, low-poly, abstract and motion-graphic scenes; data in 3D; precise or repeatable camera moves; loops;
  anything the human will want to tweak later.
- **Generated video (`cb generate video`, see `cb docs generate`) fits** photoreal people, faces, animals and nature;
  organic motion such as water, fire, cloth and crowds; live-action-looking B-roll where exact geometry does not matter.

When a request could go either way, say which you chose and why, so the human can redirect.

Read `cb docs code` first for the composition contract. This guide covers the craft on top of it.

## The loop

Work in tracer bullets: a rough scene that renders end to end first, then passes of detail, checking frames after every
pass.

1. **Start from a template.** `cb docs 3d-scene-templates` has five complete scenes (studio product, outdoor golden
   hour, interior, night city, space) with the camera rig, environment map, lights and shadows already wired. Copy the
   nearest one into a working file and change it, rather than writing the scaffolding again.
2. **Greybox.** Block out the subject and the set with primitives, set the duration and the camera move, then render:
   `cb code check scene.tsx --duration <seconds> --frames 6 --sheet review.jpg`. Done when every sampled frame frames
   the subject and the camera path stays clear of geometry.
3. **Light.** Set the environment map, key light and shadows. Done when every object sits on its shadow, glossy surfaces
   show highlights, and no large area is blown out or crushed to black.
4. **Detail.** Materials, procedural textures, instanced scatter, shader effects. Re-render after each pass.
5. **Place and look.** Put the graphic on the timeline the usual way (pending first), then `cb look` at the start,
   middle and end.

## Scene skeleton

Units are metres, y is up and the ground is y = 0. Helpers live inside the function (module scope holds only imports and
the default export); a helper that returns JSX is called as a function, `{leg(-1)}`, not used as `<Leg />`.

```tsx
import { Canvas } from '@react-three/fiber';
import { EquirectangularReflectionMapping, FloatType } from 'three';

export default function Graphic({ time, width, height }) {
  const DURATION = 8;
  const clamp01 = v => Math.min(1, Math.max(0, v));
  const ease = v => {
    const t = clamp01(v);
    return t * t * (3 - 2 * t);
  };
  const mix = (a, b, t) => a + (b - a) * t;
  const hash = n => {
    const h = Math.sin(n * 91.7 + 13.1) * 43758.5453;
    return h - Math.floor(h);
  };
  const shot = ease(time / DURATION);
  // ...environment, scatter and geometry data...
  return (
    <div style={{ width, height }}>
      <Canvas shadows gl={{ toneMappingExposure: 0.9 }} camera={{ position: [0, 1.6, 6], fov: 40, lookAt: [0, 1, 0] }}>
        {/* environment, lights, scene */}
      </Canvas>
    </div>
  );
}
```

`hash(n)` and `THREE.MathUtils.seededRandom(seed)` are the random sources: the same seed gives the same scene on every
frame.

## Camera rig

`camera={{ position, fov, lookAt, near, far }}` is applied on every frame, so a camera move is those values computed
from `time`. `lookAt` aims the camera at a point; without it (or a `rotation`) the camera faces the origin. Drive every
move from one eased `shot = ease(time / DURATION)` so it starts and lands softly.

| Move     | `position`                                               | `lookAt`                     |
| -------- | -------------------------------------------------------- | ---------------------------- |
| Orbit    | `[sin(a) * r, h, cos(a) * r]`, `a = mix(a0, a1, shot)`   | the subject                  |
| Dolly in | `mix` from a far point to a near one along the same line | the subject                  |
| Crane    | `y = mix(low, high, shot)`                               | the subject, or a rising aim |
| Tracking | the subject's position plus a fixed side offset          | the subject                  |
| Push-in  | a dolly plus a `fov` narrowing a few degrees             | fixed                        |

`fov` 28–35 suits products and hero subjects, 40–50 places and rooms. Set `far` past the farthest geometry (sky domes,
star spheres). Anything scattered (trees, rocks, buildings) is carved away from the camera path and the line of sight,
or the camera flies through it: test each scatter point's distance to the path, as the outdoor template does.

## Light

**Environment map first.** It is what metal, glass, gloss and clearcoat reflect; without one, metal renders near-black
and glass grey. Build an equirectangular HDR image as a float array (u is longitude, v runs bottom to top, values above
1 act as light sources) and attach it as the scene's environment:

```tsx
const ENV_W = 256;
const ENV_H = 128;
// Dark studio: a softbox key on the left and a strip light behind for the rim.
const studio = (u, v, c) => {
  const room = 0.015 + 0.02 * v;
  const key = Math.abs(u - 0.15) < 0.09 && Math.abs(v - 0.62) < 0.18 ? 9 : 0;
  const strip = Math.abs(u - 0.62) < 0.015 && Math.abs(v - 0.55) < 0.3 ? 14 : 0;
  return room + (key + strip) * [1, 0.92, 0.82][c];
};
const env = Float32Array.from({ length: ENV_W * ENV_H * 4 }, (_, i) => {
  const p = i >> 2;
  const c = i & 3;
  return c === 3 ? 1 : studio((p % ENV_W) / ENV_W, Math.floor(p / ENV_W) / ENV_H, c);
});
// inside <Canvas>:
<dataTexture
  attach="environment"
  args={[env, ENV_W, ENV_H]}
  type={FloatType}
  mapping={EquirectangularReflectionMapping}
  needsUpdate
/>;
```

The outdoor template builds the same thing from a sky gradient and sun; the interior one from warm walls and a bright
window. Keep it at 256x128 or smaller: it is rebuilt on every frame.

**Key, fill, rim.** One shadow-casting key (a `directionalLight` for sun, a `spotLight` with `penumbra={1}` for a studio
softbox), a soft fill (`hemisphereLight` outdoors, a weak `ambientLight` indoors) and, for products, a rim light behind.
Typical intensities: directional 2–5, spot 40–80, point 1–60 with a `distance`.

**Soft shadows.** `<Canvas shadows>` plus, on the light, `castShadow`, `shadow-mapSize={[2048, 2048]}` (4096 for large
outdoor areas), `shadow-radius` 2–8 for the edge softness and `shadow-bias` around -0.0003 (add `shadow-normalBias`
0.02–0.05 on terrain). A directional light's shadow only covers a box of ±5 m by default: fit
`shadow-camera-left/right/top/bottom/far` to the area in view, or objects beyond it cast nothing. `shadows="variance"`
gives the smoothest blur. Every visible object gets `castShadow` and every ground `receiveShadow`.

**Grounding.** Where the shadow map is too coarse to show contact, lay a dark radial decal under the object (the
interior template's `shadowDisc`): it is what keeps furniture and props from floating.

**Bounce.** Real light bounces; fake it with a weak, warm `pointLight` just above a sunlit patch, tinted like the
surface it bounces off.

**Exposure.** Tone mapping is ACES; set brightness with `gl={{ toneMappingExposure }}` (0.7–1.1) rather than by pushing
every light. Interiors are closed boxes (walls, ceiling, the far wall behind the camera) or sunlight floods in around
the edges.

**Atmosphere.** `<fog attach="fog" args={[color, near, far]}>` or `<fogExp2 attach="fog" args={[color, density]} />`,
with the fog colour matching the horizon or background. Haze and low fog come from scene fog or a shader, never from
stacked transparent planes (they show as bands).

## Materials

- `meshStandardMaterial` with `roughness` and `metalness` covers most surfaces; `flatShading` gives a faceted look.
- `meshPhysicalMaterial` adds `transmission`/`thickness`/`ior` for glass, `clearcoat` for lacquer and car paint, `sheen`
  for fabric.
- A transmissive object is invisible through another transmissive one: give liquid inside glass an opaque physical
  material with a little `emissive`.
- Large glossy surfaces (floors, roads) reflect a bright environment at grazing angles and wash out: lower their
  `envMapIntensity` to 0.3–0.5.
- `emissive` with `emissiveIntensity` for lamps, screens and windows; `meshBasicMaterial` with `toneMapped={false}` for
  neon that stays saturated.

## Geometry and subjects

- Primitives (`boxGeometry`, `sphereGeometry`, `cylinderGeometry`, `capsuleGeometry`, `coneGeometry`, `torusGeometry`).
- `latheGeometry args={[points, segments]}` revolves a profile of `new Vector2(radius, height)` points: bottles, vases,
  glasses, lamps.
- `extrudeGeometry args={[shape, { depth, bevelEnabled }]}` turns a `new Shape([...Vector2])` outline into a solid:
  gables, logos, panels.
- `bufferGeometry` with `<bufferAttribute attach="attributes-position" args={[array, 3]} />` (plus `-normal`, `-color`,
  `attach="index"`) for terrain and custom meshes; compute normals yourself (the outdoor template's heightfield does).
- **Articulated subjects** are nested groups whose origin is the joint: rotate the group, and the limb hanging below it
  swings. A walk cycle from `time` (one stride per second, legs opposite to arms, knee bend on the trailing leg):

```tsx
const phase = time * Math.PI * 2;
const swing = side => Math.sin(phase + (side < 0 ? Math.PI : 0));
const knee = side => Math.max(0, -Math.cos(phase + (side < 0 ? Math.PI : 0))) * 0.9;
const limb = (length, radius, color) => (
  <mesh castShadow position={[0, -length / 2, 0]}>
    <capsuleGeometry args={[radius, length - radius * 2, 6, 12]} />
    <meshStandardMaterial color={color} roughness={0.5} />
  </mesh>
);
const leg = side => (
  <group key={`leg${side}`} position={[0, 0.95, side * 0.13]} rotation={[0, 0, swing(side) * 0.5]}>
    {limb(0.48, 0.08, '#2e6f8e')}
    <group position={[0, -0.48, 0]} rotation={[0, 0, -knee(side)]}>
      {limb(0.47, 0.07, '#2e6f8e')}
    </group>
  </group>
);
// The figure walks along +x: <group position={[time * 1.4, Math.abs(Math.cos(phase)) * 0.06, 0]}>{[-1, 1].map(leg)}...</group>
```

- **Text** has no 3D font: set titles in a DOM layer over the `Canvas` (an absolutely positioned `div` in Inter), and
  build logos as `extrudeGeometry` from their outline.
- **Footage** from `assets` is a DOM image, not a texture: show it in a DOM layer over or under the `Canvas`.

## Instancing

Anything repeated more than a couple of dozen times (trees, rocks, buildings, crowds, grass) is one `instancedMesh`: one
draw call instead of hundreds. Each instance is a 16-number column-major matrix; this one scales by `s` and turns by `r`
around y:

```tsx
const matrices = Float32Array.from({ length: items.length * 16 }, (_, i) => {
  const { x, y, z, s, r } = items[(i / 16) | 0];
  const c = Math.cos(r) * s;
  const n = Math.sin(r) * s;
  return [c, 0, -n, 0, 0, s, 0, 0, n, 0, c, 0, x, y, z, 1][i % 16];
});
const tints = Float32Array.from({ length: items.length * 3 }, (_, i) => items[(i / 3) | 0].rgb[i % 3]);
<instancedMesh args={[undefined, undefined, items.length]} castShadow receiveShadow>
  <instancedBufferAttribute attach="instanceMatrix" args={[matrices, 16]} />
  <instancedBufferAttribute attach="instanceColor" args={[tints, 3]} />
  <coneGeometry args={[1.7, 4, 7]} />
  <meshStandardMaterial roughness={0.9} />
</instancedMesh>;
```

Multi-part objects (a trunk and a crown) are one instanced mesh per part sharing the same placement.

## Procedural textures

Build pixels with `Uint8Array.from({ length }, fn)` (or `Float32Array.from`): assigning into an array element is
rejected. Colour maps get `colorSpace={SRGBColorSpace}`; tiling gets `wrapS`/`wrapT={RepeatWrapping}` and `repeat`. Keep
textures to 256x256 or smaller, since they rebuild every frame.

```tsx
const T = 256;
const planks = Uint8Array.from({ length: T * T * 4 }, (_, i) => {
  const p = i >> 2;
  const c = i & 3;
  if (c === 3) return 255;
  const x = p % T;
  const y = Math.floor(p / T);
  const board = Math.floor(y / 32);
  const seam = y % 32 === 0 || (x + board * 97) % T === 0 ? 0.55 : 1;
  const grain = 0.88 + 0.12 * Math.sin(x * 0.09 + Math.sin(y * 0.4 + board) * 3 + board * 5);
  return Math.round(255 * clamp01([0.72, 0.55, 0.38][c] * (0.85 + hash(board) * 0.3) * grain * seam));
});
<meshStandardMaterial roughness={0.75}>
  <dataTexture
    attach="map"
    args={[planks, T, T]}
    wrapS={RepeatWrapping}
    wrapT={RepeatWrapping}
    repeat={[2, 4]}
    colorSpace={SRGBColorSpace}
    needsUpdate
  />
</meshStandardMaterial>;
```

The same pattern makes `roughnessMap`, `bumpMap`, alpha decals and emissive window maps.

## Shaders

`shaderMaterial` with `uniforms`, `vertexShader` and `fragmentShader` covers skies, planets, water and anything per
pixel. End a fragment shader with `#include <tonemapping_fragment>` and `#include <colorspace_fragment>` so its colours
match the lit scene. Pass `time` in a uniform for motion. Building blocks, all in the templates:

- **fBm noise** (space template): `hash3`, `noise3`, `fbm` for continents, clouds, terrain colour and grime.
- **Sky dome** (outdoor template): a large `BackSide` sphere with `fog={false}`, a horizon-to-zenith gradient and a sun
  disc plus glow from `dot(dir, sun)`; reuse the same sun direction for the light and the environment map.
- **Fresnel rim** (space template): `pow(1.0 - abs(dot(normal, view)), 3.0)` on a slightly larger `BackSide` shell with
  `AdditiveBlending` for atmosphere and glow.
- **Instanced shader** (night city template): read `instanceMatrix` in the vertex shader, derive window grids from world
  position so every instance gets the same window size.
- **Planar reflection** (night city template): draw the scene a second time inside `<group scale={[1, -1, 1]}>` under a
  glossy, partly transparent ground for wet streets and polished floors.

## Checks

Render with `cb code check` and look at every sheet. A scene is ready when:

- the subject is framed at the first, middle and last frame;
- the camera never clips into geometry and nothing pops in or out;
- every object meets its shadow, and shadows point away from the key light;
- highlights and reflections appear on metal, glass and gloss;
- no large area is pure white or pure black unless the look calls for it;
- motion is smooth between sampled frames (sample densely, `--frames 12`, over fast moves).

Composition errors name the rule and the source line; `cb code check` reports a runtime throw with its message. Local
names that shadow blocked globals (`window`, `document`) are rejected, so name them `pane`, `doc`. Keep a scene under a
few hundred separate meshes (instance the rest) and one or two shadow-casting lights, so frames render quickly in the
preview.
