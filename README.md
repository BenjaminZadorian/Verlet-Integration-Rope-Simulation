# Verlet Integration Rope Simulation 🪢

A 2D physics-based rope simulation built in **Godot 4.5**, featuring a player character connected to a heavy safe via a dynamic rope. The rope is simulated from scratch using **position-based Verlet integration** — no Godot physics joints or built-in rope nodes.

---

## Overview

The player is tethered to a safe by a rope that hangs, swings, and pulls realistically. The player can reel the rope in and out, climb it, pick up and place the safe, and throw it — all while the rope reacts dynamically to gravity, collisions, and tension.

---

## How the Rope Works

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

## Features

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

## 🛠️ Built With

- [Godot 4.5](https://godotengine.org/) — GDScript
- `PhysicsServer2D` for low-level rope collision queries
- `CharacterBody2D` / `RigidBody2D` for player and safe physics
