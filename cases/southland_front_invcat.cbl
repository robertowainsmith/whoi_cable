/*
 * southland_front_invcat.cbl -- Southland Front, inverse-catenary version.
 * Polyform LD-1 low drag buoy (orange, 13 kg nett buoyancy) in 110 m of water.
 *
 * Mooring, surface down:
 *   LD-1 buoy - 50 m 12 mm polypro - 3 kg downweight - 50 m polypro -
 *   5 kg subsurface float - 20 m polypro - 10 m 8 mm chain - anchor
 * 120 m of rope + 10 m of chain = 130 m of line (scope 1.18).
 *
 * Conditions: regular 2 m, 8 s waves and a steady, uniform 0.5 m/s current.
 * The buoy is free-floating (needs cable-free). Run WITHOUT -auto:
 *   cable-free -in southland_front_invcat.cbl -out southland_front_invcat.cab -terminals -sample 0.1 -snap_dt 0.2 -quiet
 *
 * ASSUMPTIONS TO CHECK
 *   - Buoy: as southland_front.cbl (LD-1 fitted to Cookes and Polyform
 *     figures, about 13.4 kg nett; Polyform 11.4 L volume would give 10.6 kg).
 *   - Downweight: 3 kg of lead, 2.7 kg (26.8 N) in water, 8 cm diameter.
 *   - Subsurface float: 5 kg nett uplift (-49 N in water), a 23 cm hard
 *     sphere of 0.8 kg mass. Rated uplift is taken as nett buoyancy.
 *   - Chain size (8 mm) was not specified; no shackles are included.
 *   - Rope and chain properties are typical values, not supplier data.
 */
Problem Description
    title = "Southland Front: inverse catenary, LD-1 buoy, 110 m depth"
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
    x-current = (0.0, 0.5) (110.0, 0.5)   /* steady, uniform 0.5 m/s */
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
chain_8mm       EA = 2.4e+07     EI = 10.0          GJ = 0.1
                 m = 1.4                           wet = 11.9
                 d = 0.031       Cdt = 0.01        Cdn = 0.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "8 mm chain, approximate"

polypro_12mm    EA = 1.2e+05     EI = 0.1           GJ = 0.1
                 m = 0.068                         wet = -0.086
                 d = 0.012       Cdt = 0.01        Cdn = 1.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "12 mm 3-strand polypropylene, floats, approximate"

Connectors
downweight_3kg  m = 3.0
                wet = 26.8
                d = 0.08
                Cdn = 1.0
                Cdt = 1.0
                comment = "3 kg lead downweight"

subfloat_5kg    m = 0.8
                wet = -49.05
                d = 0.23
                Cdn = 0.5
                Cdt = 0.5
                comment = "subsurface float, 5 kg nett uplift, 23 cm sphere"

Layout
   terminal = {
      anchor = clump
   }
   segment = {
       length = 10.0
       material = chain_8mm
       nodes = (21, 1.0)
   }
   segment = {
       length = 20.0
       material = polypro_12mm
       nodes = (21, 1.0)
   }
   connector = subfloat_5kg
   segment = {
       length = 50.0
       material = polypro_12mm
       nodes = (51, 1.0)
   }
   connector = downweight_3kg
   segment = {
       length = 50.0
       material = polypro_12mm
       nodes = (51, 1.0)
   }
   terminal = {
      buoy = ld1
   }

End
