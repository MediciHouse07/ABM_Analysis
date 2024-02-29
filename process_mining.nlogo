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

;to move
;  if not any? patches in-cone 1 180 with [pname = "boundary1" or pname = "boundary2"] [
;    fd 1
;  ] if any? patches in-cone 1 180 with [pname = "boundary1" or pname = "boundary2"] [
;    handle-obstacle
;  ]
;end
;
;to handle-obstacle
;  ; Try turning left and then right to find an alternative path
;  ifelse not any? patches in-cone 1 90 with [pname = "disable"] [
;    rt 90 ; Turn right
;  ] [
;    lt 180 ; If turning right doesn't work, turn left
;  ]
;end

to move
  if not any? patches in-cone 2 180 with [pname = "boundary1" or pname = "boundary2"] [
    fd 1
  ] if any? patches in-cone 2 180 with [pname = "boundary1" or pname = "boundary2"] [
;    ifelse destination-patch != nobody [
;      ; Store the original heading
;      let original-heading heading
      handle-obstacle
;      ; Restore the original heading
;      set heading original-heading
;    ] [
;      ; No destination set, so just stop
;      set moving? false
;    ]
  ]
end

to handle-obstacle
  ; Try turning left and then right to find an alternative path
  ifelse not any? patches in-cone 1 90 with [pname = "boundary1" or pname = "boundary2"] [
    rt 90 ; Turn right
  ] [
    lt 180 ; If turning right doesn't work, turn left
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETUP procedures ;;;;;;;;;;;;;;;;;

to setup-patches
  ; boundary can't be crossed
  ask patches with [ (pxcor <= -16 or pxcor >= 16) or (pycor <= -14 or pycor >= 14 )]
  [
    set pcolor 4 
    set pname "boundary1"
  ]
  
  ;
  
  ask patches with [(pycor >= pxcor - 1) and (pycor <= pxcor + 3 ) and (pxcor >= -4) and (pxcor <= 4)]
  [
    set pcolor 4
    set pname "boundary2"
  ]
  
  ask patches with [(pxcor > -15 and pxcor < -10) and (pycor > -2 and pycor < 3)][ set pcolor red set pname "Hungary" ]
  ask patches with [(pxcor > -3 and pxcor < 2) and (pycor > 7 and pycor < 12)][ set pcolor blue set pname "Food1" ]
  ask patches with [(pxcor > -3 and pxcor < 2) and (pycor > -10 and pycor < -5)][ set pcolor blue set pname "Food2" ]
  ;ask patches with [(pxcor > 10 and pxcor < 15) and (pycor > -2 and pycor < 3)][ set pcolor grey set pname "Full" ]
  
  ask patches with [(pxcor > 10 and pxcor < 15) and (pycor > -2 and pycor < 3) ]
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
;  set heading towards dest
  set destination-patch dest
  ;set moving_q true
  ;set state_order "moving"
end

to compute-next-state
  send-order-to-destination "Full" ; "V" is pname ; move-to one-of patches with [ pname = "PO" ]

end
