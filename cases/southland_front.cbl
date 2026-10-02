/*
 * southland_front.cbl -- Southland Front mooring: Polyform LD-1 low drag
 * buoy (orange, 13 kg nett buoyancy) on 130 m of 12 mm polypropylene rope
 * straight to the anchor in 110 m of water. No chain.
 *
 * Conditions: regular 2 m, 8 s waves and a steady current falling linearly
 * from 0.7 m/s at the surface to 0.1 m/s at the seabed.
 * The buoy is free-floating (needs cable-free), so it can be pulled under
 * if the loads demand it. Run WITHOUT -auto:
 *   cable-free -in southland_front.cbl -out southland_front.cab -terminals -sample 0.1 -snap_dt 0.2 -quiet
 *
 * ASSUMPTIONS TO CHECK
 *   - Buoy: Cookes lists 13 kg nett buoyancy; that matches Polyform's LD-1
 *     (21.8 cm dia x 48.3 cm long). The profile below is a simplified
 *     body of revolution (tapered eye end, straight body, tapered top) with
 *     about 14 L of volume, so gross buoyancy ~14.5 kg and nett ~13.4 kg
 *     with an estimated 1.1 kg buoy mass. Polyform's own chart gives 11.4 L
 *     for the LD-1, which would make the nett buoyancy nearer 10.6 kg.
 *   - Cable keeps the buoy upright. A real LD buoy on a line tilts, which
 *     changes its drag and how it sits in the water.
 *   - Drag coefficient 0.8 (upright cylinder in cross-flow); the "low drag"
 *     rating applies to towing along the buoy's axis.
 *   - Rope properties are typical for 12 mm 3-strand polypropylene.
 */
Problem Description
    title = "Southland Front: LD-1 low drag buoy, 130 m polypro, 110 m depth"
    type  = surface

Analysis Parameters
    static-relaxation = 0.1
    static-iterations = 20000
    static-tolerance  = 0.001

    relax-adapt-up    = 1.02
    relax-adapt-down  = 1.1

    static-outer-iterations = 1000
    static-initial-guess    = catenary
    static-outer-relaxation = 0.98
    static-outer-tolerance  = 0.01
    static-solution   = relaxation

    duration           = 210
    ramp-time          = 16.0      /* two wave periods */
    time-step          = 0.005     /* light buoy on a near-taut line: 0.02 s went unstable in tests */
    dynamic-relaxation = 1.0
    dynamic-iterations = 15
    dynamic-tolerance  = 1e-6

Environment
    input-type       = regular
    x-current = (0.0, 0.7) (110.0, 0.1)   /* 0.7 m/s at surface to 0.1 m/s at seabed */
    x-wind           = 5.0
    rho              = 1027
    gravity          = 9.81
    depth            = 110.0
    bottom-stiffness = 100.0
    bottom-damping   = 1.0
    forcing-method   = morison
    x-wave = (1.0, 8.0, 0.0)       /* amplitude 1 m (2 m waves), period 8 s */

Buoys
   /* Polyform LD-1, simplified: eye end tapers to full 0.218 m diameter,
      straight body, tapered top. Total length 0.483 m, ~14 L. */
   ld1      type = axisymmetric
            diameters = (0.0, 0.05) (0.10, 0.218) (0.38, 0.218) (0.483, 0.10)
            m   = 1.1
            Cdn = 0.8
            Cdt = 0.8
            Cdw = 1.0

Anchors
   clump    color = red

Materials
polypro_12mm    EA = 1.2e+05     EI = 0.1           GJ = 0.1
                 m = 0.068                         wet = -0.086
                 d = 0.012       Cdt = 0.01        Cdn = 1.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "12 mm 3-strand polypropylene, floats, approximate"

Layout
   terminal = {
      anchor = clump
   }
   segment = {
       length = 130.0
       material = polypro_12mm
       nodes = (131, 1.0)
   }
   terminal = {
      buoy = ld1
   }

End
