/*
 * slb600_pulldown.cbl -- Sealite SL-B600 marker buoy in 40 m of water,
 * pulled under by a strengthening current and released again.
 *
 * Layout, anchor upwards:
 *   anchor - 10 m of 8 mm chain - shackle - 12 mm polypropylene rope -
 *   shackle - 1 m of 8 mm chain - shackle - SL-B600 buoy
 *
 * Needs the free-floating surface buoy patch (cable-free-surface-buoy.patch).
 * Run WITHOUT -auto:
 *   cable-free -in slb600_pulldown.cbl -out slb600_pulldown.cab -terminals -sample 0.1 -snap_dt 1.0 -quiet
 *
 * ASSUMPTIONS TO CHECK
 *   - Buoy hull shape is fitted to the SL-B600 datasheet (600 mm dia,
 *     1150 mm tall, 18.5 kg, 90 L, 2.8 kg/cm immersion, 250-335 mm draft);
 *     the datasheet text gives no profile, so confirm against a drawing.
 *   - Chain size (8 mm), rope length (50 m, scope 1.5 overall), and rope
 *     and shackle properties are typical values, not manufacturer data.
 *   - Cable only allows connectors between segments, so the shackle on the
 *     buoy is an attachment at the top node of the 1 m chain.
 */
Problem Description
    title = "SL-B600 marker buoy, 40 m, chain-polypro-chain, current ramp"
    type  = surface

Analysis Parameters
    static-relaxation = 0.1
    static-iterations = 20000
    static-tolerance  = 0.001

    relax-adapt-up    = 1.02
    relax-adapt-down  = 1.1

    static-outer-iterations = 1000   /* 100 was too few: the buoy draft did not converge */
    static-initial-guess    = catenary
    static-outer-relaxation = 0.98
    static-outer-tolerance  = 0.01
    static-solution   = relaxation

    duration           = 600
    ramp-time          = 16.0      /* four wave periods */
    time-step          = 0.02      /* small buoy heaves with a ~1 s natural period */
    dynamic-relaxation = 1.0
    dynamic-iterations = 15
    dynamic-tolerance  = 1e-6

Environment
    input-type       = regular
    /* surface current 0.2 -> 2.0 -> 0.2 m/s over 600 s. Must come BEFORE
       x-current and must contain t (parser quirks). */
    x-current-modulation = 0.2 + 1.8*sin(0.00523598776*t)*sin(0.00523598776*t)
    x-current = (0.0, 1.0) (40.0, 1.0)
    x-wind           = 5.0
    rho              = 1027
    gravity          = 9.81
    depth            = 40.0
    bottom-stiffness = 100.0
    bottom-damping   = 1.0
    forcing-method   = morison
    x-wave = (0.25, 4.0, 0.0)      /* amplitude 0.25 m, period 4 s */

Buoys
   /* Sealite SL-B600, fitted profile: tapered base to 0.6 m at 0.25 m,
      0.6 m body to 0.41 m, slim 0.1 m top to 1.15 m. ~92 L total. */
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

polypro_12mm    EA = 1.2e+05     EI = 0.1           GJ = 0.1
                 m = 0.068                         wet = -0.086
                 d = 0.012       Cdt = 0.01        Cdn = 1.5
                 Cmt = 1.1       Cmn = 2.0
                 comment = "12 mm 3-strand polypropylene, floats, approximate"

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
       length = 50.0
       material = polypro_12mm
       nodes = (51, 1.0)
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
