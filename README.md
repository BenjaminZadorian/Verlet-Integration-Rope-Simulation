# Verlet Integration Rope Simulation 🪢

A 2D physics-based rope simulation built in **Godot 4.5**, featuring a player character connected to a heavy safe via a dynamic rope. The rope is simulated from scratch using **position-based Verlet integration** — no Godot physics joints or built-in rope nodes.

---

## 📽️ Overview

The player is tethered to a safe by a rope that hangs, swings, and pulls realistically. The player can reel the rope in and out, climb it, pick up and place the safe, and throw it — all while the rope reacts dynamically to gravity, collisions, and tension.

---

## ⚙️ How the Rope Works

The simulation runs entirely in `rope-verlet.gd` and is built on three core steps executed every physics frame:

### 1. Verlet Integration (`Simulate`)
Each interior rope node (excluding the two anchor points) updates its position by inferring velocity from the difference between its current and previous position, then applies gravity:

```
velocity = (currentPos - prevPos) * damping
currentPos += velocity + (gravity * delta²)
```

This gives natural, stable motion without ever storing velocity explicitly.

### 2. Constraint Solving (`ApplyConstraints`)
After simulation, the distance between every adjacent pair of nodes is corrected to match the target `ropeSegmentLength`. This runs **30 iterations per frame** to converge on a stable solution. Anchor points (player and safe) are pinned before each pass.

### 3. Collision Resolution (`HandleCollisions`)
Each rope node queries the physics world using `PhysicsServer2D` with a circle shape. If a node overlaps the tilemap layer, it is pushed out along the collision normal and its stored previous position is adjusted to apply a small bounce.

---

## 🎮 Controls

| Action | Input |
|---|---|
| Move | `move_left` / `move_right` |
| Jump | `jump` (with coyote time + jump buffer) |
| Reel rope in | `reel_in` (while on floor) |
| Reel rope out | `reel_out` |
| Climb rope | `climb_rope` (while safe is above player) |
| Pick up / place safe | `pickup_safe` |
| Charge throw | Hold `throw_safe` (while holding safe) |
| Release throw | Release `throw_safe` |

> Input actions must be configured in **Project → Input Map**.

---

## 🧩 Features

### Rope
- Verlet-integrated rope with configurable segment count, length, and size
- 30 constraint iterations per frame for stable, stiff rope behaviour
- Per-node circle collision against the tilemap layer
- Tautness detection — rope reports when it is pulled to near-maximum length
- Tension forces propagated to the safe when taut
- Dynamic segment insertion/removal for reeling in and out

### Player
- Standard `CharacterBody2D` movement with gravity, friction, and air resistance
- **Coyote time** and **jump buffer** for responsive jumping
- Movement speed halved when the rope is taut
- **Rope climbing** — player snaps along the rope nodes toward the safe
- Jump disabled while carrying the safe (toggleable with `debugMode`)

### Safe
- `RigidBody2D` pulled by rope tension when taut
- Can be **picked up** when the player is close enough
- Can be **thrown** with a charge mechanic — hold to build power, release to launch
  - A charge indicator line changes from green → red as throw strength increases
  - Collision exception applied on the frame of throw so the safe clears the player cleanly
- Placement validation — checks for overlaps before putting the safe down
- Fully freezes when picked up; velocity cleared cleanly on release

---

## 🗂️ Project Structure

```
├── rope-verlet.gd     # Rope simulation: Verlet integration, constraints, collision
├── safe.gd            # Safe physics: tension response, pickup, throw, placement check
├── player.gd          # Player controller: movement, reeling, climbing, throwing
```

### Expected Scene Tree

```
World
├── Player (CharacterBody2D)          ← player.gd
│   ├── JumpBufferTimer
│   ├── CoyoteTimer
│   ├── ThrowIndicator (Line2D)
│   └── Flipper (Node2D)
│       ├── RopeAttachPoint (Marker2D)
│       └── SafePickupPoint (Marker2D)
├── Safe (RigidBody2D)                ← safe.gd
│   ├── CollisionShape2D
│   └── RopeAttachPoint (Marker2D)
└── RopeSimulation (Node2D)           ← rope-verlet.gd
    └── RopeVisual (Line2D)
```

---

## 🔧 Configuration

Key parameters are exposed as variables at the top of each script:

### `rope-verlet.gd`
| Variable | Default | Description |
|---|---|---|
| `ropeSegmentBase` | `15` | Starting number of rope segments |
| `ropeSegmentLength` | `5.0` | Rest length of each segment (px) |
| `ropeSegmentMin` | `4` | Minimum segments before auto-pickup |
| `gravity` | `Vector2(0, 9.8)` | Gravity applied per frame |
| `damping` | `0.9` | Velocity damping (lower = more drag) |
| `constraintRuns` | `30` | Constraint iterations per frame |
| `collisionRadius` | `12.0` | Circle radius for node collision checks |
| `bounceFactor` | `0.1` | Bounciness on collision |
| `maxTautness` | `0.98` | Ratio at which rope is considered taut |

### `player.gd`
| Variable | Default | Description |
|---|---|---|
| `speed` | `200` | Horizontal movement speed |
| `jumpHeight` | `-400.0` | Jump velocity |
| `gravity` | `980.0` | Player gravity |
| `climbingSpeed` | `40.0` | Speed when climbing rope |
| `minThrowStrength` | `100.0` | Minimum throw impulse |
| `maxThrowStrength` | `500.0` | Maximum throw impulse |

### `safe.gd`
| Variable | Default | Description |
|---|---|---|
| `tensionScale` | `80.0` | Multiplier on rope tension force |
| `playerClearDistance` | `40.0` | Distance before re-enabling collision after throw |

---

## 🚀 Getting Started

1. Clone or download the repository.
2. Open the project in **Godot 4.5**.
3. Set up input actions in **Project → Project Settings → Input Map**:
   - `move_left`, `move_right`, `jump`
   - `reel_in`, `reel_out`, `climb_rope`
   - `pickup_safe`, `throw_safe`
4. Attach the scripts to the correct nodes as shown in the scene tree above.
5. Make sure the **TileMap** (or other colliders) is on **collision layer 1** to match `rope-verlet.gd`'s `collisionLayer`.
6. Run the scene.

---

## 🛠️ Built With

- [Godot 4.5](https://godotengine.org/) — GDScript
- `PhysicsServer2D` for low-level rope collision queries
- `CharacterBody2D` / `RigidBody2D` for player and safe physics
