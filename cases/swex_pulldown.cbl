/*
 * swex_pulldown.cbl -- surface float that is dragged under and resurfaces.
 *
 * Needs the free-floating surface buoy patch (cable-free-surface-buoy.patch):
 * with forcing-method = morison on a surface problem, the patched solver
 * computes buoyancy, drag area and current depth from the buoy's
 * instantaneous draft relative to the local wave surface.
 *
 * Current: uniform 1 m/s profile scaled by x-current-modulation, rising
 * from 1 to 4.5 m/s and back over 600 s (deliberately fast, for a demo).
 * NOTE: x-current-modulation must come BEFORE x-current (parser bug), and
 * must contain t (a bare constant crashes cable).
 *
 * Static solution: catenary guess + relaxation (the shooting solver cannot
 * return a submerged surface buoy). Run WITHOUT -auto:
 *   cable -in swex_pulldown.cbl -out swex_pulldown.cab -terminals -sample 0.1 -snap_dt 1.0 -quiet
 */
Problem Description
    title = "SWEX mooring: surface float pulled under by a strengthening current"
    type  = surface

Analysis Parameters
    static-relaxation = 0.1
    static-iterations = 20000
    static-tolerance  = 0.001

    relax-adapt-up    = 1.02
    relax-adapt-down  = 1.1

    static-outer-iterations = 100
    static-initial-guess    = catenary
    static-outer-relaxation = 0.98
    static-outer-tolerance  = 0.01
    static-solution   = relaxation

    duration           = 600
    ramp-time = 16.0
    time-step          = 0.05    /* 0.1 */
    dynamic-relaxation = 1.0
    dynamic-iterations = 15
    dynamic-tolerance  = 1e-6

Environment
    input-type       = regular
    x-current-modulation = 1.0 + 3.5*sin(0.00523598776*t)*sin(0.00523598776*t)
    x-current = (0.0, 1.0) (43.31, 1.0)
    x-wind	     = 7.17
    rho		     = 1027
    gravity	     = 9.81
    depth            = 43.31
    bottom-stiffness = 100.0
    bottom-damping   = 1.0
    forcing-method   = morison
    x-wave = (0.5, 8.0, 0.0)
    
Buoys
   ssar		type = axisymmetric
 		diameters = (0.0, 0.235) (1.39, 0.235) (1.4, 1.27) (2.14, 1.27)
		m = 227
		Cdn = 0.5
		Cdt = 0.5
                Cdw = 1.3

Anchors
   clump	color = red

Materials	
chain_1_2       EA = 6.44e+07    EI = 10.0          GJ = 0.1
                 m = 3.7335        		   wet = 31.8455
                 d = 0.0495      Cdt = 0.01        Cdn = 0.5
				 Cmt = 1.1        Cmn = 2.0
                 comment = "1/2 Trawler Chain"

	/*
	 * revised AxPack Cmt, Cmn from 1.5, 2.0 
	 * after coeff3.dat
	 */

AxPack		EA = 8.0e7	 EI = 30000.0       GJ = 0.1
		 m = 10.02   			   wet = 70.82
		 d = 0.0762	Cdt = 0.065   	   Cdn = 0.8
				 Cmt = 1.1         Cmn = 2.0
		 comment = "Length = 0.76 m, with SRS at both ends"

Connectors
shackle		d = 0.01	/* just something to release moments */
		wet = 0.01
		m = 0.01

Layout
   terminal = {
      anchor = clump
   }
   segment = {
       length = 45
       material = chain_1_2
       nodes = (91, 1.0)
   }
   connector = shackle
   segment = {
       length = 0.76
       material = AxPack
       nodes = (3, 1.0)
   }
   connector = shackle
   segment = {
       length = 3.5
       material = chain_1_2
       nodes = (9, 1.0)
   }
   connector = shackle
   segment = {
       length = 0.76
       material = AxPack
       nodes = (3, 1.0)
   }
   connector = shackle
   segment = {
       length = 7.0
       material = chain_1_2
       nodes = (15, 1.0)
   }
   connector = shackle
   segment = {
       length = 0.76
       material = AxPack
       nodes = (3, 1.0)
   }
   connector = shackle
   segment = {
       length = 22.5 + 0.5	/* 0.5 for srs-swivel-srs at top */
       material = chain_1_2
       nodes = (24, 1.0)
   } 
   terminal = {
      buoy = ssar
   }

End
