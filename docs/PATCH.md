# The free-floating surface buoy patch

`patches/cable-free-surface-buoy.patch` lets a surface buoy in a 2D WHOI Cable
dynamic run be pulled under by current or waves, and resurface when the load
eases. `scripts/build.sh` applies it to a copy of the source to build
`cable-free`.

## Summary

Stock Cable can't simulate this: with Morison forcing it fixes the buoy's
draft at its full height, so the buoy has constant buoyancy and no hydrostatic
restoring force. The patch recomputes the draft at every solver iteration from
the buoy's position relative to the local wave surface. Buoyancy, drag area,
the depth at which current is sampled, and wind drag all follow that draft.

It touches three files (`solver/dynamic_2d.c`, `solver/waves.c`,
`include/model.h`) and adds about 70 lines. All other problem types and
forcing options are unchanged.

In a test ramping the current 1 → 4.5 → 1 m/s on Cable's SWEX example mooring
(case `swex_pulldown`), the patched build submerged the spar float at
3.6–3.8 m/s. It reached 8.5–8.8 m depth at 4.5 m/s, against a stock static
solution of 8.9 m, and resurfaced as the current eased.

## Background: how stock Cable treats a surface buoy

Cable solves the static equilibrium first, then uses it as the initial
condition for the dynamic run. The static relaxation solver already handles a
submerged surface float, reporting it "submerged at max draft". The shooting
solver, which `-auto` relies on, fails in that case.

In the dynamic run, the top node's boundary condition depends on
`forcing-method`:

| Forcing method | How the buoy moves | Can it sink and resurface? |
|---|---|---|
| `velocity` | vertical motion prescribed | no |
| `wave-follower` | follows the wave surface by construction | no |
| `morison` | free body under Newton's second law | no: draft fixed at full height |

In the `morison` branch of `solver/dynamic_2d.c`, the stock code sets
`buoy->draft = buoy->max_draft`, commented "added for drifter work". A
commented-out line shows that a version using the actual draft once existed.
The result is that a surface buoy under Morison forcing has no hydrostatic
spring: it doesn't heave with the waves through buoyancy changes, and a float
that should be pulled under in strong current can't show that transition or
its recovery.

## The changes

The new code applies only when `type = surface` and
`forcing-method = morison`, and not during `-auto`'s steady relaxation
(`dynstat`). Notation follows Cable's internal 2D coordinates: $x_b$ is the
height of the buoy's base above the seabed, $y$ its horizontal position, $h_s$
the height of the mean sea surface above the seabed, $h$ the buoy height, and
$r(z)$ the buoy radius at height $z$ above its base.

### 1. Sea-surface elevation (`solver/waves.c`, `include/model.h`)

Cable had functions for wave particle velocity and acceleration and for the
surface's vertical velocity, but not for the surface's height. The new
`WaveSurfaceElevation(t, y)` returns

```math
\eta(y,t) = R(t)\sum_i a_i \cos(k_i y - \omega_i t - \phi_i), \qquad R(t) = \min\left(\frac{t}{T_{\mathrm{ramp}}}, 1\right)
```

The sum runs over the `x-wave` components for regular waves, or Cable's stored
spectral components for random seas. It uses the same amplitudes,
wavenumbers, phases and ramp as the existing kinematics, so $\partial\eta/\partial t$
matches `WaveSurfaceVelocity`. It returns zero during `-auto`'s relaxation,
where Cable switches waves off.

### 2. Instantaneous draft (`solver/dynamic_2d.c`)

The fixed draft is replaced by the buoy's actual depth below the local surface:

```math
d = \max\left(0,\; h_s + \eta(y_b, t) - x_b\right)
```

### 3. Buoyancy and drag area at that draft

These use Cable's existing `Buoyancy()` and `ProjectedArea()`, which
integrate the buoy profile and cap at full submergence:

```math
B(d) = \rho g \int_0^{\min(d,h)} \pi r(z)^2\,dz, \qquad A_p(d) = \int_0^{\min(d,h)} 2\,r(z)\,dz
```

The horizontal drag term becomes $\tfrac12 \rho C_{dn} A_p(d)$ in place of the
fixed `Mdr`. The added-mass term `Marma` is left at its stock, fully
submerged value.

### 4. Current depth and wind

The current is sampled at the middle of the submerged part instead of at the
mean surface, $x_c = x_b + \tfrac12\min(d, h)$. Wind drag is computed as
before while any part of the buoy is above the surface, and set to zero when
$d > h$.

## Scientific justification

A surface float's buoyancy depends on how much of it is under water. Fixing it
at the fully submerged value removes both the physics that keeps a float at
the surface and the physics that lets it be dragged under. The patch restores
both by applying Archimedes' principle to the instantaneous draft.

**Hydrostatic restoring force.** While the buoy floats, pushing it down by
$\Delta z$ increases its buoyancy by $\Delta B = \rho g A_{wp} \Delta z$, where
$A_{wp}$ is the waterplane area. This spring holds the buoy at the surface and
makes it heave with the waves. For the SWEX spar float (1.27 m diameter at the
waterline) it is about 12.8 kN/m.

**Saturation at full submergence.** Once fully submerged, $A_{wp} = 0$ and
buoyancy stops increasing at $B_{max} = \rho g V_{total}$. The float can then
carry at most its reserve buoyancy, $B_{max} - mg$, and at equilibrium the
vertical pull of the line at the buoy equals that reserve.

**Why the float stops at a finite depth.** The vertical pull at the top is
roughly $V_{top} \approx H_{top} \tan\alpha$, where $H_{top}$ is the horizontal
load at the buoy (its own drag, plus wind while emergent) and $\alpha$ is the
line's angle above horizontal there. With a fixed line length, a sinking float
swings downstream, the line near the top flattens, $\alpha$ falls, and
$V_{top}$ drops until it matches the reserve buoyancy. The stopping mechanism
changes from the hydrostatic spring to the much weaker geometric stiffness of
the mooring, so once under, the float is very sensitive to current. Cable's own
static solutions for SWEX show this: the float base sits 1.7 m deep at 1 m/s
and 2.0 m at 3 m/s, but 3.9 m at 4.0 m/s, 8.9 m at 4.5 m/s and 12.9 m at
5.0 m/s.

**Current and wind at the right place.** A submerged buoy sits below the
surface, so sampling the current at the mean surface overstates its drag in a
sheared profile. A fully submerged buoy has no area exposed to the wind.

**Consistency with Cable's own solvers.** The stock static relaxation solver
already treats a surface float submerged at maximum draft. The patch makes the
dynamic Morison branch obey the same physics, so a dynamic run is consistent
with its static starting point and, in slowly varying current, tracks the
static solution.

## Verification

All tests used the SWEX mooring (spar float, 13 mm chain, 43.3 m depth),
`time-step = 0.05` s and 15 iterations. These are internal consistency
checks, not comparisons with field data.

1. **Regression.** A `velocity`-forced SWEX run gave bit-identical output with
   the stock and patched builds.
2. **Steady current.** At 1 m/s with small waves, the dynamic buoy sat at a
   draft of 1.68 m against the static 1.67 m, heaved with the waves, and did
   not drift.
3. **Wave phase.** While floating, the draft computed from the reconstructed
   surface stayed nearly constant, so the surface function is in phase with
   the buoy's motion.
4. **Pull-down and recovery** (case `swex_pulldown`):

| Quantity | Patched dynamic run | Stock static solution |
|---|---|---|
| Current at which the float submerges | 3.6–3.8 m/s | ≈ 3.85 m/s |
| Float base depth at 4.5 m/s | 8.5–8.8 m | 8.9 m |
| Top tension at 4.5 m/s | 10.24–10.28 kN | 10.29 kN |

The float top first dipped below passing wave crests at about 3.4 m/s. The
dynamic run submerges slightly earlier than the static threshold because waves
add to the load.

## Limitations

The patch is internally consistent but has not been validated against
observations or another dynamic code.

1. **Solver linearisation.** The change of buoyancy with height is not in the
   solver's Jacobian; the draft is updated between iterations. Small, light
   buoys on near-taut lines can need a much smaller `time-step` (0.005 s for
   the LD-1 cases here). Treat convergence warnings as a reason to reduce it.
2. **Added mass.** `Marma` stays at the fully submerged value, so added mass is
   overstated while the buoy floats. This matters little in long swell but
   more in short, steep seas and for snatch loads.
3. **Vertical drag.** Vertical drag still uses the side-projected area and the
   normal drag coefficient, as stock Cable does, so heave damping is uncertain.
4. **Wave forces.** Waves act through the change in draft plus Morison drag
   and inertia at the base node. There is no diffraction, radiation damping or
   slamming. That's reasonable for floats small compared with the wavelength,
   not for large buoys in short waves.
5. **Current on the buoy.** The current is sampled at one depth, the middle of
   the submerged part.
6. **No tilt.** The buoy stays upright. A real buoy leaning on its line
   changes its drag area, waterplane area and reserve buoyancy. This matters
   most for small, elongated floats such as the LD-1.
7. **Wind.** Stock emergent-area treatment until fully submerged, then zero.
   No gusts or wind-wave interaction.
8. **2D only.** `solver/dynamic_3d.c` is unpatched, so 3D runs, and current or
   waves at an angle, aren't covered.
9. **Static start.** A run still starts from Cable's static solution. With
   `-auto` (shooting method), a case that starts submerged may fail; use the
   relaxation solver for those.
10. **Limited testing.** Checks were made on a handful of moorings and float
    shapes, mostly in regular waves.

## References

Journal details were cited from memory and should be checked before use in a
publication.

- WHOI Cable source code: https://github.com/jgobat/cable
- Gobat, J. I. and Grosenbaugh, M. A. WHOI Cable v2.0: time domain numerical
  simulation of moored and towed oceanographic systems. User's manual, Woods
  Hole Oceanographic Institution technical report (`docs/WHOI_Cable_manual-2.0.pdf`).
- Gobat, J. I. and Grosenbaugh, M. A. (2001). Application of the generalized-α
  method to the time integration of the cable dynamics equations. *Computer
  Methods in Applied Mechanics and Engineering*, 190, 4817–4829.
- Gobat, J. I. and Grosenbaugh, M. A. (2006). Time-domain numerical simulation
  of ocean cable structures. *Ocean Engineering*, 33, 1373–1400.
