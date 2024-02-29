breed [bullets bullet]

turtles-own[ moving? destination-patch initial_patch] ; every turtle ; destination-patch to setup
patches-own[ pname ]


;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  ca
  setup-patches
  setup-hr
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;; GO - MAIN CYCLE ;;;;;;;;;;;;;;;;;;

to go
  tick
  check-moving

end

to move
  fd 1
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETUP procedures ;;;;;;;;;;;;;;;;;

to setup-patches
  ask patches [ set pcolor 4 ]
  ask patches with [(pxcor > -15 and pxcor < -10) and (pycor > -2 and pycor < 3)][ set pcolor red set pname "Hungary" ]
  ask patches with [(pxcor > -3 and pxcor < 2) and (pycor > 7 and pycor < 12)][ set pcolor blue set pname "Food1" ]
  ask patches with [(pxcor > -3 and pxcor < 2) and (pycor > -10 and pycor < -5)][ set pcolor blue set pname "Food2" ]
  ;ask patches with [(pxcor > 10 and pxcor < 15) and (pycor > -2 and pycor < 3)][ set pcolor grey set pname "Full" ]
  
  ask patches with [(pxcor > 10 and pxcor < 15) and (pycor > -2 and pycor < 3) and
                   (pxcor - 10)<(pycor + 2)
                   ]
                   [ set pcolor grey set pname "Full" ]

  setup-label

end

to setup-label
  ask patches with [pxcor = -12 and pycor = 1 ] [set plabel "Hungary"]      ; just labels
  ask patches with [pxcor = 0 and pycor = 10 ] [set plabel "Food1"]
  ask patches with [pxcor = 0 and pycor = -7 ] [set plabel "Food2"]
  ask patches with [pxcor = 13 and pycor = 1] [set plabel "Full"]
end

to setup-hr
  create-bullets 10
    [ ; place  workers on the view
      set shape "dot" set color 58
      set_initial_location "Hungary"
      let selected-patch initial_patch
      setxy [pxcor] of selected-patch [pycor] of selected-patch
    ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;; GO procedures ;;;;;;;;;;;;;;;;;;;;

to check-moving
  ask turtles
  [
    compute-next-state
    move
  ]
end

to set_initial_location [d]
  let init one-of patches with [pname = d]
  set initial_patch init
end

to send-order-to-destination [ d ]
  let dest one-of patches with [pname = d]
  set heading towards dest
  set destination-patch dest
  ;set moving_q true
  ;set state_order "moving"
end

to compute-next-state
  send-order-to-destination "Full" ; "V" is pname ; move-to one-of patches with [ pname = "PO" ]

end
