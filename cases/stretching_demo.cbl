/*
 * stretching_demo.cbl -- shows the effect of wave kinematic stretching on a
 * slack surface mooring in waves with (almost) no current.
 *
 * Layout, anchor upwards:
 *   anchor - 10 m of 8 mm chain - shackle - 55 m of 12 mm polyester rope
 *   (sinks) - shackle - 1 m of 8 mm chain - shackle - SL-B600 buoy
 * in 30 m of water: scope 2.2, so the rope hangs in a slack loop and the
 * buoy has very little horizontal restoring force.
 *
 * Conditions: regular 3 m, 12 s waves travelling in +x (left to right in the
 * plots). The static solve needs some current, so it starts at a uniform
 * 0.05 m/s that decays to zero with a 20 s time constant
 * (x-current-modulation). After that the only forcing is the waves.
 *
 * Run it twice with cable-free and compare where the buoy sits:
 *   scripts/run_case.sh stretching_demo                        (Wheeler, default)
 *   CABLE_STRETCHING=none scripts/run_case.sh stretching_demo  (stock kinematics)
 * Stock Cable sets wave velocities to zero above the mean water level, so
 * the buoy feels no orbital flow on crests but the full flow in troughs, and
 * walks up-wave (to the left). With Wheeler stretching it stays near its
 * starting position. Neither includes Stokes drift or second-order wave
 * drift forces, which in reality push a surface buoy slowly down-wave.
 *
 * ASSUMPTIONS: SL-B600 profile and chain, shackle and rope properties are
 * the typical values used in slb600_waves; the polyester is approximate.
 */
Problem Description
    title = "Stretching demo: SL-B600, slack polyester, 30 m, 3 m 12 s waves, no current"
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

    duration           = 400
    ramp-time          = 24.0      /* two wave periods */
    time-step          = 0.02
    dynamic-relaxation = 1.0
    dynamic-iterations = 15
    dynamic-tolerance  = 1e-6

Environment
    input-type       = regular
    x-current-modulation = exp(0.0 - 0.05*t)   /* decays with a 20 s time constant; must come before x-current and contain t */
    x-current = (0.0, 0.05) (30.0, 0.05)  /* 0.05 m/s for the static solve, decaying to 0 */
    x-wind           = 0.0
    rho              = 1027
    gravity          = 9.81
    depth            = 30.0
    bottom-stiffness = 100.0
    bottom-damping   = 1.0
    forcing-method   = morison
    x-wave = (1.5, 12.0, 0.0)      /* amplitude 1.5 m (3 m waves), period 12 s */

Buoys
   /* Sealite SL-B600, fitted profile (as in slb600_waves) */
   slb600   type = axisymmetric
            diameters = (0.0, 0.30) (0.25, 0.60) (0.41, 0.60) (0.42, 0.10) (1.15, 0.10)
            m   = 18.5
            Cdn = 0.8
            Cdt = 0.8
            Cdw = 1.0

Anchors
   clump    color = red

Materials
chain_8mm       EA = 2.4e+07     EI = 10.0          GJ = 0.1
                 m = 1.4                           wet = 11.9
                 d = 0.031       Cdt = 0.01        Cdn = 0.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "8 mm chain, approximate"

polyester_12mm  EA = 4.0e+05     EI = 0.1           GJ = 0.1
                 m = 0.11                          wet = 0.28
                 d = 0.012       Cdt = 0.01        Cdn = 1.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "12 mm polyester rope, sinks, approximate"

Connectors
shackle_10mm    d = 0.04
                m = 0.17
                wet = 1.45
                comment = "10 mm shackle, chain to rope"

shackle_16mm    d = 0.06
                m = 0.8
                wet = 6.8
                comment = "16 mm shackle at the buoy"

Layout
   terminal = {
      anchor = clump
   }
   segment = {
       length = 10.0
       material = chain_8mm
       nodes = (21, 1.0)
   }
   connector = shackle_10mm
   segment = {
       length = 55.0
       material = polyester_12mm
       nodes = (56, 1.0)
   }
   connector = shackle_10mm
   segment = {
       length = 1.0
       material = chain_8mm
       nodes = (6, 1.0)
       attachments = shackle_16mm : (6)
   }
   terminal = {
      buoy = slb600
   }

End
