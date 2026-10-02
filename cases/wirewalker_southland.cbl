/*
 * wirewalker_southland.cbl -- Wirewalker profiler surface mooring in 100 m,
 * translated from the ProteusDS Oceanographic Designer project
 * Wirewalker_100m_template_mooring_SOUTHLAND.POA (Designer 2.72.4).
 * Environment: the POA's "100m_weak_flow" case (1 m, 9 s waves; current
 * 0.5 m/s at the surface falling linearly to 0 at the seabed; no wind).
 *
 * Mooring, anchor upward (component data from the POA parts entries):
 *   anchor - shackle - 15 m 1/2" trawlex chain - shackle/link/shackle -
 *   3 m 18 mm nylon - shackle/link/shackle + EdgeTech Port release +
 *   shackle/swivel/shackle - 37.5 m 18 mm nylon with 4 x 280 mm floats at
 *   20 m - shackle/link/shackle - 80 m 18 mm nylon - shackle/swivel/shackle +
 *   2 x 20 kg downweights + hardware - 75 m 3/16" jacketed wire with the
 *   Wirewalker 3 m below the buoy - shackle/link/shackle - surface buoy.
 *   210.5 m of line in 100 m of water (scope 2.1).
 *
 * Needs the free-floating surface buoy patch. Run WITHOUT -auto:
 *   cable-free -in wirewalker_southland.cbl -out wirewalker_southland.cab -terminals -sample 0.1 -snap_dt 0.2 -quiet
 *
 * TRANSLATION CHOICES TO CHECK
 *   - Cable only allows one connector between segments, so hardware in a
 *     row (e.g. shackle-link-shackle, release, shackle-swivel-shackle) is
 *     lumped into one connector with the summed mass and wet weight. The
 *     hardware's length (under 1 m in total at each joint) is ignored.
 *   - The anchor has no mass or type in the POA; Cable holds it fixed.
 *     The shackle between anchor and chain is left out (0.36 kg).
 *   - Surface buoy: the POA lists a 0.9 m x 1 m cylinder but also 275 kg
 *     net uplift and 61 kg mass. A full 0.9 m x 1 m cylinder would give
 *     about 590 kg net, so the hull here is 0.9 m diameter and 0.51 m tall,
 *     which matches the 275 kg uplift. Its drag and wind area are therefore
 *     smaller than a 1 m tall buoy's.
 *   - Clamp positions: the POA does not say which end they are measured
 *     from. The floats are 20 m from the bottom of the 37.5 m rope (17.5 m
 *     if from the top), and the Wirewalker is fixed 3 m below the buoy. In
 *     reality the Wirewalker climbs and falls along the wire.
 *   - Wirewalker size: the POA's 16.5 mm x 152.5 mm instrument size is a
 *     placeholder; a 0.4 m drag diameter is assumed here.
 *   - Rope stiffness from the POA's 7.7% stretch at 50% of 64.7 kN breaking
 *     strength (EA = 4.2e5 N). Wire EA, and all drag coefficients, are
 *     typical values, not from the POA.
 *   - Waves: the POA's 1 m wave height is used as a regular 1 m, 9 s wave.
 */
Problem Description
    title = "Wirewalker 100 m template mooring, Southland (from ProteusDS POA)"
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

    duration           = 216
    ramp-time          = 18.0      /* two wave periods */
    time-step          = 0.01
    dynamic-relaxation = 1.0
    dynamic-iterations = 15
    dynamic-tolerance  = 1e-6

Environment
    input-type       = regular
    x-current = (0.0, 0.5) (100.0, 0.0)  /* 0.5 m/s at surface, 0 at seabed */
    x-wind           = 0.0
    rho              = 1027
    gravity          = 9.81
    depth            = 100.0
    bottom-stiffness = 100.0
    bottom-damping   = 1.0
    forcing-method   = morison
    x-wave = (0.5, 9.0, 0.0)       /* amplitude 0.5 m (1 m waves), period 9 s */

Buoys
   /* Del Mar surface buoy: 0.9 m diameter; hull height set so the net
      uplift is the POA's 275 kg (61 kg mass) */
   ww_buoy  type = axisymmetric
            diameters = (0.0, 0.9) (0.514, 0.9)
            m   = 61.0
            Cdn = 0.8
            Cdt = 0.8
            Cdw = 1.0

Anchors
   clump    color = red

Materials
trawlex_1_2in   EA = 6.44e+07    EI = 10.0          GJ = 0.1
                 m = 3.676                         wet = 31.31
                 d = 0.0495      Cdt = 0.01        Cdn = 0.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "1/2 in ACCO mid-link trawlex chain (Peerless), 2.47 lb/ft"

nylon_18mm      EA = 4.2e+05     EI = 0.01          GJ = 0.01
                 m = 0.178                         wet = 0.173
                 d = 0.018       Cdt = 0.005       Cdn = 1.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "18 mm Oliveira Astra 3-strand nylon, SG 1.14, MBS 64.7 kN"

wire_3_16in     EA = 1.2e+06     EI = 0.1           GJ = 0.1
                 m = 0.110                         wet = 0.759
                 d = 0.00648     Cdt = 0.005       Cdn = 1.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "3/16 in 3x19 jacketed wire (Mooring Systems Inc), 4000 lbf"

Connectors
/* shackle + sling link + shackle (Crosby 1/2 in G-2130, 5/8 in G-341) */
hw_A            m = 1.197
                wet = 10.17
                d = 0.05
                Cdn = 1.0
                Cdt = 1.0
                comment = "shackle-link-shackle"

/* hw_A + EdgeTech Port LF release (7 kg, 3 kg wet) + shackle-swivel-shackle */
release_assy    m = 9.51
                wet = 50.78
                d = 0.0883
                Cdn = 1.0
                Cdt = 1.0
                comment = "hardware + acoustic release + hardware"

/* shackle-swivel-shackle + 2 x 20 kg steel downweights + 2 shackles +
   shackle-link-shackle + shackle-swivel-shackle */
downweight_assy m = 44.54
                wet = 379.4
                d = 0.25
                Cdn = 1.2
                Cdt = 1.2
                comment = "2 x 20 kg Del Mar downweights with hardware"

/* four 280 mm IP Castro N-280 floats, 8.5 kg uplift and 3 kg mass each */
floats_4x280    m = 12.0
                wet = -333.5
                d = 0.56
                Cdn = 0.5
                Cdt = 0.5
                comment = "4 x 280 mm trawl floats, 34 kg total uplift"

/* Wirewalker integrated unit: 40 kg, 1 kg buoyant in water */
wirewalker      m = 40.0
                wet = -9.81
                d = 0.4
                Cdn = 1.0
                Cdt = 1.0
                comment = "Del Mar Wirewalker with typical sensor loadout"

Layout
   terminal = {
      anchor = clump
   }
   segment = {
       length = 15.0
       material = trawlex_1_2in
       nodes = (31, 1.0)
   }
   connector = hw_A
   segment = {
       length = 3.0
       material = nylon_18mm
       nodes = (7, 1.0)
   }
   connector = release_assy
   segment = {
       length = 37.5
       material = nylon_18mm
       nodes = (76, 1.0)
       attachments = floats_4x280 : (41)
   }
   connector = hw_A
   segment = {
       length = 80.0
       material = nylon_18mm
       nodes = (81, 1.0)
   }
   connector = downweight_assy
   segment = {
       length = 75.0
       material = wire_3_16in
       nodes = (76, 1.0)
       attachments = wirewalker : (73), hw_A : (76)
   }
   terminal = {
      buoy = ww_buoy
   }

End
