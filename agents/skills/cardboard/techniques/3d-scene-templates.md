# 3D scene templates

Five complete scenes to start from; `cb docs 3d-scenes` explains the techniques they use. Each one renders as written:
copy the nearest into a working file, check it with `cb code check <file> --duration <seconds> --sheet review.jpg`, then
replace the subject and the set while keeping the rig, the environment map and the lighting.

## Studio product

A product on a pedestal in a dark studio: a softbox environment map, a spot key with soft shadows, a warm rim, a
revolved glass bottle with an opaque liquid inside, and a slow eased orbit with a push-in. Duration 6 s.

```tsx
import { Canvas } from '@react-three/fiber';
import { EquirectangularReflectionMapping, FloatType, Vector2 } from 'three';

export default function Graphic({ time, width, height }) {
  const DURATION = 6;
  const clamp01 = v => Math.min(1, Math.max(0, v));
  const ease = v => {
    const t = clamp01(v);
    return t * t * (3 - 2 * t);
  };
  const mix = (a, b, t) => a + (b - a) * t;

  // Studio environment: dark room, a large softbox key on the left, a strip light behind for the rim.
  const ENV_W = 256;
  const ENV_H = 128;
  const studio = (u, v, c) => {
    const room = 0.015 + 0.02 * v;
    const key = Math.abs(u - 0.15) < 0.09 && Math.abs(v - 0.62) < 0.18 ? 9 : 0;
    const strip = Math.abs(u - 0.62) < 0.015 && Math.abs(v - 0.55) < 0.3 ? 14 : 0;
    const warm = c === 0 ? 1 : c === 1 ? 0.92 : 0.82;
    return room + (key + strip) * warm;
  };
  const env = Float32Array.from({ length: ENV_W * ENV_H * 4 }, (_, i) => {
    const p = i >> 2;
    const c = i & 3;
    return c === 3 ? 1 : studio((p % ENV_W) / ENV_W, Math.floor(p / ENV_W) / ENV_H, c);
  });

  // Camera rig: a slow eased orbit around the product, aimed at its shoulder.
  const shot = ease(time / DURATION);
  const angle = mix(-0.5, 0.45, shot);
  const radius = mix(5.6, 4.8, shot);
  const target = [0, 0.9, 0];

  // Bottle profile, revolved: radius by height (x = radius, y = height).
  const bottle = [
    [0, 0],
    [0.42, 0],
    [0.48, 0.04],
    [0.5, 0.12],
    [0.5, 1.0],
    [0.46, 1.1],
    [0.32, 1.18],
    [0.16, 1.22],
    [0.15, 1.3],
    [0, 1.3],
  ].map(([x, y]) => new Vector2(x, y));
  const liquid = [
    [0, 0.06],
    [0.44, 0.06],
    [0.45, 0.12],
    [0.45, 0.82],
    [0, 0.82],
  ].map(([x, y]) => new Vector2(x, y));

  return (
    <div style={{ width, height, background: '#0b0a09' }}>
      <Canvas
        shadows
        gl={{ toneMappingExposure: 1.05 }}
        camera={{ position: [Math.sin(angle) * radius, 1.6, Math.cos(angle) * radius], fov: 32, lookAt: target }}
      >
        <color attach="background" args={['#0b0a09']} />
        <dataTexture
          attach="environment"
          args={[env, ENV_W, ENV_H]}
          type={FloatType}
          mapping={EquirectangularReflectionMapping}
          needsUpdate
        />
        <spotLight
          castShadow
          position={[-3, 4, 2]}
          angle={0.45}
          penumbra={1}
          intensity={70}
          color="#fff1dc"
          shadow-mapSize={[2048, 2048]}
          shadow-radius={8}
          shadow-bias={-0.0002}
        />
        <spotLight position={[1.5, 2.5, -3]} angle={0.5} penumbra={1} intensity={45} color="#ffd8a8" />

        <group position={[0, 0.3, 0]}>
          <mesh castShadow>
            <latheGeometry args={[bottle, 96]} />
            <meshPhysicalMaterial transmission={1} thickness={0.6} ior={1.5} roughness={0.04} color="#ffffff" />
          </mesh>
          <mesh>
            <latheGeometry args={[liquid, 96]} />
            <meshPhysicalMaterial color="#a3500c" emissive="#3a1403" roughness={0.15} clearcoat={1} />
          </mesh>
          <mesh castShadow position={[0, 1.48, 0]}>
            <cylinderGeometry args={[0.24, 0.24, 0.36, 64]} />
            <meshStandardMaterial color="#d9b25a" metalness={1} roughness={0.22} />
          </mesh>
        </group>

        <mesh castShadow receiveShadow position={[0, 0.15, 0]}>
          <cylinderGeometry args={[0.95, 1.0, 0.3, 96]} />
          <meshStandardMaterial color="#3a3632" roughness={0.85} />
        </mesh>
        <mesh receiveShadow rotation={[-Math.PI / 2, 0, 0]}>
          <circleGeometry args={[12, 64]} />
          <meshStandardMaterial color="#1a1816" roughness={0.6} />
        </mesh>
        <fog attach="fog" args={['#0b0a09', 5, 11]} />
      </Canvas>
    </div>
  );
}
```

## Outdoor golden hour

A cabin in a forest clearing at sunset: a heightfield terrain with vertex colour, about 600 instanced trees kept off the
camera path, a shader sky dome with a sun, a matching environment map, long low-sun shadows over a large fitted shadow
camera, distance fog, and a dolly-in with a slight crane down. Duration 10 s.

```tsx
import { Canvas } from '@react-three/fiber';
import { BackSide, EquirectangularReflectionMapping, FloatType, Shape, Vector2 } from 'three';

export default function Graphic({ time, width, height }) {
  const DURATION = 10;
  const clamp01 = v => Math.min(1, Math.max(0, v));
  const ease = v => {
    const t = clamp01(v);
    return t * t * (3 - 2 * t);
  };
  const mix = (a, b, t) => a + (b - a) * t;
  const hash = (x, z) => {
    const h = Math.sin(x * 127.1 + z * 311.7) * 43758.5453;
    return h - Math.floor(h);
  };
  // Smooth value noise and fBm: the same function shapes the terrain and places the trees on it.
  const noise = (x, z) => {
    const xi = Math.floor(x);
    const zi = Math.floor(z);
    const fx = x - xi;
    const fz = z - zi;
    const u = fx * fx * (3 - 2 * fx);
    const w = fz * fz * (3 - 2 * fz);
    return mix(mix(hash(xi, zi), hash(xi + 1, zi), u), mix(hash(xi, zi + 1), hash(xi + 1, zi + 1), u), w);
  };
  const fbm = (x, z) => noise(x, z) * 0.5 + noise(x * 2.1, z * 2.1) * 0.25 + noise(x * 4.3, z * 4.3) * 0.125;
  // Open ground around the cabin and along the camera's path, so nothing scattered blocks the shot.
  const pathDistance = (x, z) => {
    const t = clamp01(((x - 0) * 6 + (z + 4) * 22) / (6 * 6 + 22 * 22));
    return Math.hypot(x - 6 * t, z + 4 - 22 * t);
  };
  const clearing = (x, z) => clamp01((Math.min(Math.hypot(x, z + 4) - 4, pathDistance(x, z)) - 3) / 8);
  const groundHeight = (x, z) => (fbm(x * 0.06, z * 0.06) - 0.45) * 7 * clearing(x, z);

  // Terrain: a heightfield grid with analytic normals and per-vertex colour.
  const SIZE = 120;
  const GRID = 120;
  const verts = (GRID + 1) * (GRID + 1);
  const at = k => [((k % (GRID + 1)) / GRID - 0.5) * SIZE, (Math.floor(k / (GRID + 1)) / GRID - 0.5) * SIZE];
  const positions = Float32Array.from({ length: verts * 3 }, (_, i) => {
    const [x, z] = at((i / 3) | 0);
    return [x, groundHeight(x, z), z][i % 3];
  });
  const normals = Float32Array.from({ length: verts * 3 }, (_, i) => {
    const [x, z] = at((i / 3) | 0);
    const dx = groundHeight(x + 0.5, z) - groundHeight(x - 0.5, z);
    const dz = groundHeight(x, z + 0.5) - groundHeight(x, z - 0.5);
    const n = [-dx, 1, -dz];
    return n[i % 3] / Math.hypot(n[0], n[1], n[2]);
  });
  const colors = Float32Array.from({ length: verts * 3 }, (_, i) => {
    const [x, z] = at((i / 3) | 0);
    const dirt = 1 - clamp01((Math.hypot(x, z + 4) - 3) / 4);
    const g = fbm(x * 0.4, z * 0.4);
    return [mix(0.2 + g * 0.1, 0.36, dirt), mix(0.3 + g * 0.12, 0.27, dirt), mix(0.1, 0.18, dirt)][i % 3];
  });
  const index = Uint32Array.from({ length: GRID * GRID * 6 }, (_, i) => {
    const cell = (i / 6) | 0;
    const a = Math.floor(cell / GRID) * (GRID + 1) + (cell % GRID);
    return [a, a + GRID + 1, a + 1, a + 1, a + GRID + 1, a + GRID + 2][i % 6];
  });

  // Forest: one instanced mesh per part, placed by rejection sampling outside the clearing.
  const trees = Array.from({ length: 700 }, (_, k) => {
    const x = (hash(k, 1.3) - 0.5) * 110;
    const z = (hash(k, 7.9) - 0.5) * 110 - 10;
    return { x, z, s: 0.8 + hash(k, 3.1) * 0.9, r: hash(k, 5.7) * 6.28 };
  }).filter(t => clearing(t.x, t.z) > 0.25);
  const treeMatrices = (lift, sy) =>
    Float32Array.from({ length: trees.length * 16 }, (_, i) => {
      const { x, z, s, r } = trees[(i / 16) | 0];
      const c = Math.cos(r) * s;
      const n = Math.sin(r) * s;
      const y = groundHeight(x, z) + lift * s;
      return [c, 0, -n, 0, 0, sy * s, 0, 0, n, 0, c, 0, x, y, z, 1][i % 16];
    });

  // Sun low in the west; the sky shader, the environment map and the light all use this direction.
  const sun = [-0.62, 0.16, -0.77];
  const sky = (dx, dy, dz, c) => {
    const up = clamp01(dy);
    const horizon = [1.0, 0.62, 0.36][c];
    const zenith = [0.22, 0.38, 0.62][c];
    const d = clamp01(dx * sun[0] + dy * sun[1] + dz * sun[2]);
    return mix(horizon, zenith, Math.pow(up, 0.5)) + Math.pow(d, 64) * 30 * [1, 0.8, 0.55][c] + Math.pow(d, 6) * 0.6;
  };
  const ENV_W = 128;
  const ENV_H = 64;
  const env = Float32Array.from({ length: ENV_W * ENV_H * 4 }, (_, i) => {
    const p = i >> 2;
    const c = i & 3;
    if (c === 3) return 1;
    const phi = ((p % ENV_W) / ENV_W) * Math.PI * 2;
    const theta = (Math.floor(p / ENV_W) / ENV_H) * Math.PI;
    const dy = -Math.cos(theta);
    const r = Math.sin(theta);
    return dy < 0 ? [0.12, 0.1, 0.06][c] : sky(-Math.cos(phi) * r, dy, Math.sin(phi) * r, c);
  });

  const gable = new Shape([new Vector2(-2, 0), new Vector2(2, 0), new Vector2(0, 1.4)]);

  // Camera rig: a slow dolly toward the cabin with a slight crane down, aimed at the door.
  const shot = ease(time / DURATION);
  const eye = [mix(6, 3.5, shot), mix(4.2, 2.4, shot), mix(16, 7, shot)];
  const target = [0, 1.6, -4];

  return (
    <div style={{ width, height }}>
      <Canvas
        shadows
        gl={{ toneMappingExposure: 0.9 }}
        camera={{ position: eye, fov: 40, near: 0.1, far: 400, lookAt: target }}
      >
        <dataTexture
          attach="environment"
          args={[env, ENV_W, ENV_H]}
          type={FloatType}
          mapping={EquirectangularReflectionMapping}
          needsUpdate
        />
        <fog attach="fog" args={['#e0a070', 20, 110]} />
        <mesh scale={300}>
          <sphereGeometry args={[1, 48, 24]} />
          <shaderMaterial
            side={BackSide}
            depthWrite={false}
            fog={false}
            uniforms={{ sun: { value: sun } }}
            vertexShader={`varying vec3 vDir; void main() { vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`}
            fragmentShader={`
              uniform vec3 sun; varying vec3 vDir;
              void main() {
                vec3 d = normalize(vDir);
                float up = clamp(d.y, 0.0, 1.0);
                vec3 col = mix(vec3(1.0, 0.62, 0.36), vec3(0.22, 0.38, 0.62), pow(up, 0.5));
                float s = clamp(dot(d, normalize(sun)), 0.0, 1.0);
                col += pow(s, 900.0) * vec3(6.0, 5.0, 3.6) + pow(s, 8.0) * vec3(0.6, 0.35, 0.15);
                gl_FragColor = vec4(col, 1.0);
                #include <tonemapping_fragment>
                #include <colorspace_fragment>
              }`}
          />
        </mesh>
        <hemisphereLight args={['#ffd2a8', '#3a4a2a', 0.5]} />
        <directionalLight
          castShadow
          position={[sun[0] * 60, sun[1] * 60 + 4, sun[2] * 60]}
          intensity={3.2}
          color="#ffc58a"
          shadow-mapSize={[4096, 4096]}
          shadow-radius={3}
          shadow-bias={-0.0004}
          shadow-normalBias={0.04}
          shadow-camera-left={-45}
          shadow-camera-right={45}
          shadow-camera-top={45}
          shadow-camera-bottom={-45}
          shadow-camera-far={150}
        />

        <mesh receiveShadow>
          <bufferGeometry>
            <bufferAttribute attach="attributes-position" args={[positions, 3]} />
            <bufferAttribute attach="attributes-normal" args={[normals, 3]} />
            <bufferAttribute attach="attributes-color" args={[colors, 3]} />
            <bufferAttribute attach="index" args={[index, 1]} />
          </bufferGeometry>
          <meshStandardMaterial vertexColors roughness={1} />
        </mesh>

        <instancedMesh args={[undefined, undefined, trees.length]} castShadow receiveShadow>
          <instancedBufferAttribute attach="instanceMatrix" args={[treeMatrices(1, 1), 16]} />
          <cylinderGeometry args={[0.18, 0.28, 2, 6]} />
          <meshStandardMaterial color="#4a3222" roughness={1} />
        </instancedMesh>
        <instancedMesh args={[undefined, undefined, trees.length]} castShadow receiveShadow>
          <instancedBufferAttribute attach="instanceMatrix" args={[treeMatrices(4.2, 1.5), 16]} />
          <coneGeometry args={[1.7, 4, 7]} />
          <meshStandardMaterial color="#26401f" roughness={0.9} flatShading />
        </instancedMesh>

        <group position={[0, 0, -4]}>
          <mesh castShadow receiveShadow position={[0, 1.2, 0]}>
            <boxGeometry args={[4, 2.4, 3]} />
            <meshStandardMaterial color="#6b4428" roughness={0.9} />
          </mesh>
          {[-1, 1].map(side => (
            <mesh key={side} castShadow position={[side * 1.0, 3.12, 0]} rotation={[0, 0, side * -0.62]}>
              <boxGeometry args={[2.6, 0.14, 3.5]} />
              <meshStandardMaterial color="#3b2a20" roughness={0.8} />
            </mesh>
          ))}
          <mesh castShadow position={[0, 2.4, -1.5]}>
            <extrudeGeometry args={[gable, { depth: 3, bevelEnabled: false }]} />
            <meshStandardMaterial color="#6b4428" roughness={0.9} />
          </mesh>
          <mesh position={[0, 0.9, 1.51]}>
            <boxGeometry args={[0.8, 1.6, 0.04]} />
            <meshStandardMaterial color="#3a2414" />
          </mesh>
          {[-1.2, 1.2].map(x => (
            <mesh key={x} position={[x, 1.4, 1.51]}>
              <boxGeometry args={[0.7, 0.6, 0.04]} />
              <meshStandardMaterial color="#ffb35c" emissive="#ff9a3c" emissiveIntensity={2} />
            </mesh>
          ))}
        </group>
      </Canvas>
    </div>
  );
}
```

## Interior

A living room in afternoon sun: a closed room with a window opening, sunlight casting the window frame across a
procedural plank floor, a warm bounce light, a practical lamp, contact-shadow decals under the furniture, and a slow
push-in. Duration 8 s.

```tsx
import { Canvas } from '@react-three/fiber';
import { EquirectangularReflectionMapping, FloatType, RepeatWrapping, SRGBColorSpace } from 'three';

export default function Graphic({ time, width, height }) {
  const DURATION = 8;
  const clamp01 = v => Math.min(1, Math.max(0, v));
  const ease = v => {
    const t = clamp01(v);
    return t * t * (3 - 2 * t);
  };
  const mix = (a, b, t) => a + (b - a) * t;
  const hash = n => {
    const h = Math.sin(n * 91.7) * 43758.5453;
    return h - Math.floor(h);
  };

  // Oak planks: one tile of eight boards with grain, tiled across the floor.
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
    const tone = (0.85 + hash(board) * 0.3) * grain * seam;
    return Math.round(255 * clamp01([0.72, 0.55, 0.38][c] * tone));
  });

  // Soft dark disc under furniture: a cheap contact shadow where the shadow map is too coarse.
  const C = 64;
  const contact = Uint8Array.from({ length: C * C * 4 }, (_, i) => {
    const p = i >> 2;
    const d = Math.hypot((p % C) / C - 0.5, Math.floor(p / C) / C - 0.5) * 2;
    return (i & 3) === 3 ? Math.round(150 * Math.pow(clamp01(1 - d), 2)) : 0;
  });

  // Interior environment: warm walls, a bright window to the left.
  const ENV_W = 128;
  const ENV_H = 64;
  const env = Float32Array.from({ length: ENV_W * ENV_H * 4 }, (_, i) => {
    const p = i >> 2;
    const c = i & 3;
    if (c === 3) return 1;
    const u = (p % ENV_W) / ENV_W;
    const v = Math.floor(p / ENV_W) / ENV_H;
    const pane = Math.abs(u - 0.25) < 0.08 && v > 0.45 && v < 0.85 ? 3 : 0;
    return [0.55, 0.47, 0.38][c] * 0.5 + pane;
  });

  // Camera rig: a slow push-in across the room.
  const shot = ease(time / DURATION);
  const eye = [mix(1.6, 1.1, shot), mix(1.55, 1.4, shot), mix(6.2, 4.6, shot)];
  const target = [-0.3, 0.75, 0];

  const wall = '#e9e3d9';
  const box = (key, position, size, color, rough = 0.8) => (
    <mesh key={key} castShadow receiveShadow position={position}>
      <boxGeometry args={size} />
      <meshStandardMaterial color={color} roughness={rough} />
    </mesh>
  );
  const shadowDisc = (key, x, z, w, d) => (
    <mesh key={key} position={[x, 0.004, z]} rotation={[-Math.PI / 2, 0, 0]}>
      <planeGeometry args={[w, d]} />
      <meshBasicMaterial transparent depthWrite={false}>
        <dataTexture attach="map" args={[contact, C, C]} needsUpdate />
      </meshBasicMaterial>
    </mesh>
  );

  return (
    <div style={{ width, height }}>
      <Canvas shadows gl={{ toneMappingExposure: 0.8 }} camera={{ position: eye, fov: 42, lookAt: target }}>
        <color attach="background" args={['#f4efe6']} />
        <dataTexture
          attach="environment"
          args={[env, ENV_W, ENV_H]}
          type={FloatType}
          mapping={EquirectangularReflectionMapping}
          needsUpdate
        />
        <ambientLight intensity={0.12} color="#ffeedd" />
        {/* Sun through the window: the shadow camera is fitted to the room so the frame's shadow stays sharp. */}
        <directionalLight
          castShadow
          position={[-9, 5, -1.5]}
          intensity={5}
          color="#ffe2b8"
          shadow-mapSize={[4096, 4096]}
          shadow-radius={2}
          shadow-bias={-0.0003}
          shadow-camera-left={-6}
          shadow-camera-right={6}
          shadow-camera-top={6}
          shadow-camera-bottom={-6}
        />
        {/* Bounce: warm light thrown back up from the sunlit floor patch. */}
        <pointLight position={[-0.8, 0.4, 0.6]} intensity={1.4} distance={6} color="#ffcf9a" />
        <pointLight castShadow position={[2.1, 1.55, -1.2]} intensity={1.6} distance={5} color="#ffb870" />

        {/* Floor and walls; the left wall is built around a window opening. */}
        <mesh receiveShadow rotation={[-Math.PI / 2, 0, 0]}>
          <planeGeometry args={[8, 8]} />
          <meshStandardMaterial roughness={0.75} envMapIntensity={0.35}>
            <dataTexture
              attach="map"
              args={[planks, T, T]}
              wrapS={RepeatWrapping}
              wrapT={RepeatWrapping}
              repeat={[2, 4]}
              colorSpace={SRGBColorSpace}
              needsUpdate
            />
          </meshStandardMaterial>
        </mesh>
        {box('back', [0, 1.5, -2.5], [8, 3, 0.1], wall, 0.95)}
        {box('left-low', [-2.5, 0.35, 2], [0.1, 0.7, 9], wall, 0.95)}
        {box('left-high', [-2.5, 2.75, 2], [0.1, 0.5, 9], wall, 0.95)}
        {box('left-back', [-2.5, 1.5, -2.05], [0.1, 3, 0.9], wall, 0.95)}
        {box('left-front', [-2.5, 1.5, 4.3], [0.1, 3, 5.4], wall, 0.95)}
        {box('right', [3.5, 1.5, 2], [0.1, 3, 9], wall, 0.95)}
        {box('ceiling', [0.5, 3.05, 2], [6.2, 0.1, 9], '#f3efe8', 0.95)}
        {[-1.6, 0, 1.6].map(z => box(`mullion-${z}`, [-2.5, 1.5, z], [0.12, 1.8, 0.06], '#3b3530', 0.6))}
        {box('transom', [-2.5, 1.5, 0], [0.12, 0.06, 3.3], '#3b3530', 0.6)}

        {/* Sofa, coffee table, lamp, plant. */}
        <group position={[0.2, 0, -1.6]}>
          {box('seat', [0, 0.25, 0], [2.4, 0.4, 0.9], '#9a9187')}
          {box('back', [0, 0.65, -0.35], [2.4, 0.6, 0.22], '#958c82')}
          {box('arm-l', [-1.25, 0.45, 0], [0.22, 0.5, 0.9], '#8f877d')}
          {box('arm-r', [1.25, 0.45, 0], [0.22, 0.5, 0.9], '#8f877d')}
          {box('cushion-a', [-0.6, 0.58, -0.12], [0.5, 0.42, 0.14], '#7f8f6a')}
          {box('cushion-b', [0.65, 0.58, -0.12], [0.5, 0.42, 0.14], '#c4673e')}
        </group>
        {shadowDisc('sofa', 0.2, -1.55, 3.2, 1.6)}
        <group position={[0.2, 0, 0]}>
          {box('top', [0, 0.42, 0], [1.3, 0.05, 0.7], '#b98d5c', 0.5)}
          {[-0.6, 0.6].flatMap(x =>
            [-0.3, 0.3].map(z => box(`leg-${x}-${z}`, [x, 0.2, z], [0.05, 0.4, 0.05], '#8a6640'))
          )}
          {box('book', [-0.25, 0.47, 0.05], [0.32, 0.05, 0.24], '#2f4a5c')}
          <mesh castShadow position={[0.3, 0.5, -0.05]}>
            <cylinderGeometry args={[0.05, 0.045, 0.11, 24]} />
            <meshStandardMaterial color="#f2efe9" roughness={0.3} />
          </mesh>
        </group>
        {shadowDisc('table', 0.2, 0, 1.8, 1.1)}
        <group position={[2.1, 0, -1.2]}>
          <mesh castShadow position={[0, 0.8, 0]}>
            <cylinderGeometry args={[0.015, 0.015, 1.6, 8]} />
            <meshStandardMaterial color="#b08a4a" metalness={1} roughness={0.3} />
          </mesh>
          <mesh position={[0, 1.65, 0]}>
            <cylinderGeometry args={[0.16, 0.24, 0.3, 32, 1, true]} />
            <meshStandardMaterial color="#f7f1e6" emissive="#ffcf95" emissiveIntensity={0.6} side={2} />
          </mesh>
        </group>
        <group position={[-1.9, 0, -1.9]}>
          <mesh castShadow position={[0, 0.2, 0]}>
            <cylinderGeometry args={[0.2, 0.16, 0.4, 24]} />
            <meshStandardMaterial color="#efe9df" roughness={0.6} />
          </mesh>
          {Array.from({ length: 14 }, (_, k) => {
            const a = k * 2.4;
            const h = 0.5 + hash(k) * 0.9;
            return (
              <mesh
                key={k}
                castShadow
                position={[Math.cos(a) * 0.18, h, Math.sin(a) * 0.18]}
                rotation={[Math.sin(a) * 0.7, a, Math.cos(a) * 0.7]}
              >
                <sphereGeometry args={[0.16, 8, 6]} />
                <meshStandardMaterial color="#3f6b39" roughness={0.7} />
              </mesh>
            );
          })}
        </group>
      </Canvas>
    </div>
  );
}
```

## Night city

A street canyon at night: instanced towers with an unlit shader that draws lit windows from world position, neon signs
with coloured point lights, a wet street that reflects a mirrored copy of the city, exponential fog, and a crane from
street level to the rooftops. Duration 8 s.

```tsx
import { Canvas } from '@react-three/fiber';
import { DoubleSide } from 'three';

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

  // Two rows of towers lining a street that runs along -z.
  const towers = Array.from({ length: 80 }, (_, k) => {
    const side = k % 2 === 0 ? -1 : 1;
    const row = Math.floor(k / 2);
    const w = 5 + hash(k) * 4;
    const h = 8 + Math.pow(hash(k + 40), 2) * 45;
    return { x: side * (8 + w / 2 + hash(k + 7) * 3), z: 6 - row * 7.5, w, d: 5 + hash(k + 3) * 2, h };
  });
  const matrices = Float32Array.from({ length: towers.length * 16 }, (_, i) => {
    const { x, z, w, d, h } = towers[(i / 16) | 0];
    return [w, 0, 0, 0, 0, h, 0, 0, 0, 0, d, 0, x, h / 2, z, 1][i % 16];
  });

  // Facades are unlit: lit windows come from world position, so every tower gets the same window size.
  const facade = {
    uniforms: { fogColor: { value: [0.006, 0.007, 0.016] } },
    vertexShader: `
      varying vec3 vWorld; varying vec3 vNormal; varying float vDepth;
      void main() {
        vec4 world = modelMatrix * instanceMatrix * vec4(position, 1.0);
        vWorld = world.xyz;
        vNormal = normalize(mat3(modelMatrix * instanceMatrix) * normal);
        vec4 view = viewMatrix * world;
        vDepth = -view.z;
        gl_Position = projectionMatrix * view;
      }`,
    fragmentShader: `
      uniform vec3 fogColor; varying vec3 vWorld; varying vec3 vNormal; varying float vDepth;
      float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
      void main() {
        vec3 n = normalize(vNormal);
        vec2 face = abs(n.x) > 0.5 ? vWorld.zy : vWorld.xy;
        vec2 cell = floor(face / vec2(1.6, 1.4));
        vec2 f = fract(face / vec2(1.6, 1.4));
        float pane = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.75);
        float lit = step(0.62, hash(cell + floor(vWorld.x * 0.1) * 17.0));
        vec3 warm = mix(vec3(1.0, 0.72, 0.42), vec3(0.65, 0.8, 1.0), hash(cell * 1.7));
        float shade = abs(n.x) > 0.5 ? 0.6 : 1.0;
        vec3 col = vec3(0.007, 0.008, 0.013) * shade + pane * lit * warm * 0.7;
        if (abs(n.y) > 0.5) col = vec3(0.02);
        float fog = 1.0 - exp(-0.00012 * vDepth * vDepth);
        gl_FragColor = vec4(mix(col, fogColor, clamp(fog, 0.0, 1.0)), 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
  };

  const neon = [
    { x: -7.6, y: 4, z: -6, w: 0.25, h: 3, color: '#ff2d95' },
    { x: 7.6, y: 5, z: -14, w: 0.25, h: 4, color: '#2de2ff' },
    { x: -7.6, y: 6, z: -24, w: 0.25, h: 2.5, color: '#ffb02d' },
    { x: 7.6, y: 3.5, z: -33, w: 0.25, h: 3, color: '#9d5cff' },
  ];
  // The city, drawn once upright and once mirrored under the wet street.
  const city = mirror => (
    <group scale={[1, mirror ? -1 : 1, 1]}>
      <instancedMesh args={[undefined, undefined, towers.length]}>
        <instancedBufferAttribute attach="instanceMatrix" args={[matrices, 16]} />
        <boxGeometry />
        <shaderMaterial {...facade} side={mirror ? DoubleSide : 0} />
      </instancedMesh>
      {neon.map(sign => (
        <mesh key={sign.z} position={[sign.x, sign.y, sign.z]}>
          <boxGeometry args={[sign.w, sign.h, 1.6]} />
          <meshBasicMaterial color={sign.color} toneMapped={false} />
        </mesh>
      ))}
    </group>
  );

  // Camera rig: a crane from street level up to roof height, drifting forward.
  const shot = ease(time / DURATION);
  const eye = [mix(1.5, 0, shot), mix(1.4, 16, shot), mix(16, 6, shot)];
  const target = [0, mix(4, 9, shot), -30];

  return (
    <div style={{ width, height }}>
      <Canvas camera={{ position: eye, fov: 45, far: 600, lookAt: target }}>
        <color attach="background" args={['#05060c']} />
        <fogExp2 attach="fog" args={['#05060c', 0.011]} />
        <ambientLight intensity={0.15} />
        {neon.map(sign => (
          <pointLight
            key={sign.z}
            position={[sign.x * 0.8, sign.y, sign.z]}
            color={sign.color}
            intensity={60}
            distance={22}
          />
        ))}
        {city(false)}
        {city(true)}
        {/* Wet asphalt: glossy and partly see-through, so the mirrored city reads as a reflection. */}
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, -60]}>
          <planeGeometry args={[200, 200]} />
          <meshStandardMaterial color="#10121a" roughness={0.35} metalness={0.3} transparent opacity={0.82} />
        </mesh>
      </Canvas>
    </div>
  );
}
```

## Space

A planet from orbit: a shader surface with fBm continents, clouds, ice caps and night-side city lights, a Fresnel
atmosphere shell, a point starfield, a moon, and an orbit from the night side into daylight with a push-in. Duration 10
s.

```tsx
import { Canvas } from '@react-three/fiber';
import { AdditiveBlending, BackSide } from 'three';

export default function Graphic({ time, width, height }) {
  const DURATION = 10;
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

  const sun = [1, 0.25, 0.35];
  // Starfield: points on a far sphere, brightness varied per star.
  const STARS = 3000;
  const starPositions = Float32Array.from({ length: STARS * 3 }, (_, i) => {
    const k = (i / 3) | 0;
    const z = hash(k) * 2 - 1;
    const a = hash(k + 0.5) * Math.PI * 2;
    const r = Math.sqrt(1 - z * z) * 400;
    return [Math.cos(a) * r, z * 400, Math.sin(a) * r][i % 3];
  });
  const starColors = Float32Array.from({ length: STARS * 3 }, (_, i) => {
    const b = 0.25 + Math.pow(hash(((i / 3) | 0) + 0.25), 6) * 2;
    return b * [1, 0.95, 0.9][i % 3];
  });

  const noise = `
    float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
    float noise3(vec3 p) {
      vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
      return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
                 mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
    }
    float fbm(vec3 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 6; i++) { v += a * noise3(p); p *= 2.03; a *= 0.5; } return v; }`;
  const surface = `
    uniform vec3 sun; uniform float spin; varying vec3 vLocal; varying vec3 vNormal;
    ${noise}
    void main() {
      float c = cos(spin), s = sin(spin);
      vec3 p = vec3(c * vLocal.x + s * vLocal.z, vLocal.y, -s * vLocal.x + c * vLocal.z);
      float land = smoothstep(0.47, 0.5, fbm(p * 1.8));
      float ice = smoothstep(0.82, 0.9, abs(p.y));
      vec3 ocean = mix(vec3(0.005, 0.02, 0.07), vec3(0.01, 0.05, 0.13), fbm(p * 6.0));
      vec3 ground = mix(vec3(0.07, 0.12, 0.04), vec3(0.24, 0.19, 0.11), fbm(p * 5.0 + 3.0));
      vec3 albedo = mix(mix(ocean, ground, land), vec3(0.9), ice);
      float cloud = smoothstep(0.55, 0.75, fbm(p * 3.0 + vec3(spin * 0.4, 0.0, 0.0)));
      float day = dot(normalize(vNormal), normalize(sun));
      float lit = smoothstep(-0.08, 0.25, day);
      vec3 col = mix(albedo, vec3(0.95), cloud) * lit * 1.3;
      col += (1.0 - lit) * land * (1.0 - cloud) * step(0.66, fbm(p * 90.0)) * smoothstep(0.45, 0.6, fbm(p * 7.0)) * vec3(1.0, 0.62, 0.28) * 1.2;
      col += pow(max(dot(reflect(-normalize(sun), normalize(vNormal)), vec3(0, 0, 1)), 0.0), 40.0) * (1.0 - land) * 0.4 * lit;
      gl_FragColor = vec4(col, 1.0);
      #include <tonemapping_fragment>
      #include <colorspace_fragment>
    }`;
  const atmosphere = `
    uniform vec3 sun; varying vec3 vNormal; varying vec3 vView;
    void main() {
      float rim = pow(1.0 - abs(dot(normalize(vNormal), normalize(vView))), 3.0);
      float day = smoothstep(-0.3, 0.4, dot(normalize(vNormal), normalize(sun)));
      gl_FragColor = vec4(vec3(0.3, 0.6, 1.0) * rim * day * 1.6, 1.0);
    }`;
  const vertex = `
    varying vec3 vLocal; varying vec3 vNormal; varying vec3 vView;
    void main() {
      vLocal = normalize(position);
      vNormal = normalize(mat3(modelMatrix) * normal);
      vec4 world = modelMatrix * vec4(position, 1.0);
      vView = cameraPosition - world.xyz;
      gl_Position = projectionMatrix * viewMatrix * world;
    }`;

  // Camera rig: orbit a quarter turn from the night side into daylight while pushing in.
  const shot = ease(time / DURATION);
  const angle = mix(-1.9, -0.6, shot);
  const distance = mix(7.5, 4.6, shot);

  return (
    <div style={{ width, height }}>
      <Canvas
        camera={{
          position: [Math.sin(angle) * distance, 0.6, Math.cos(angle) * distance],
          fov: 35,
          far: 1000,
          lookAt: [0, 0, 0],
        }}
      >
        <color attach="background" args={['#000004']} />
        <points>
          <bufferGeometry>
            <bufferAttribute attach="attributes-position" args={[starPositions, 3]} />
            <bufferAttribute attach="attributes-color" args={[starColors, 3]} />
          </bufferGeometry>
          <pointsMaterial size={1.4} sizeAttenuation={false} vertexColors toneMapped={false} />
        </points>
        <mesh>
          <sphereGeometry args={[1.5, 128, 64]} />
          <shaderMaterial
            uniforms={{ sun: { value: sun }, spin: { value: time * 0.03 } }}
            vertexShader={vertex}
            fragmentShader={surface}
          />
        </mesh>
        <mesh scale={1.06}>
          <sphereGeometry args={[1.5, 96, 48]} />
          <shaderMaterial
            uniforms={{ sun: { value: sun } }}
            vertexShader={vertex}
            fragmentShader={atmosphere}
            side={BackSide}
            transparent
            blending={AdditiveBlending}
            depthWrite={false}
          />
        </mesh>
        <directionalLight position={sun} intensity={2.4} />
        <mesh position={[6, 1.6, -12]}>
          <sphereGeometry args={[0.42, 64, 32]} />
          <meshStandardMaterial color="#9b978f" roughness={1} />
        </mesh>
      </Canvas>
    </div>
  );
}
```
