      set terminal svg
      set tmargin 0
      set bmargin 3
      set border -1 lw 0.5
      unset border
      set style line 1 linetype -1 linewidth 1.5
          # ...   style for the curve itself
      set style arrow 1 size screen .017,20 filled linetype -1 linewidth .5
      set xtics axis (-6.0,-4.0,-2.0,2.0,4.0,6.0)
      set ytics axis (-2.0,-1.0,1.0,2.0)
      set xzeroaxis linetype -1 linewidth 0.5
      set yzeroaxis linetype -1 linewidth 0.5
      set label "x" at 6.6,0
      set label "y" at 0,2.6
      set samples 300
      unset key
      set size square 0.35,0.35
      set arrow from -6.0,0 to 6.18,0 arrowstyle 1
      set arrow from 0,-2.0 to 0,2.2 arrowstyle 1
      set xrange [-6.0:6.0]
      set yrange [-2.0:2.0]
plot atan(1/x) with lines linestyle 1 
