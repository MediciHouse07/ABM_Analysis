extensions [
  csv
]

;; breeds variables
breed [workers worker]          ; staff - agents
breed [orders order]            ; orders sent by Purchasing Office to Vendors
breed [copy_orders copy_order]  ; a copy of an order sent by Purchasing Office to Account Payable
breed [invoices invoice]        ; invoces generated by Vendors to Accounts Payable

;; breeds-own variables
workers-own [
  state-worker      ;  "waiting", "service", "not-working-time"
  time-limit        ;  a variable containing the deadline for the service
  working-with      ;  the order being worked on

  duration
  service-time      ;  a variable to register the time spent in the service
]

orders-own [        ; order to be fulfilled and escaped ;state-order time-limit working-with duration destination-patch my_invoice_arrived? my_copy_order_arrived? order-arrival-time
  state-order       ; "waiting-for-worker","service", "moving", "delay"
  time-limit        ; limit of time to conclude a task/start the next activity
  working-with      ; the worker being workting with

  duration

  destination-patch ; the patch where the order has to move

  my_invoice_arrived?     ; a variable to check the arrival of an invoice
  my_copy_order_arrived?  ; to check the arrival of a copy of the order

  order-arrival-time ; KPI variable
]

copy_orders-own [
  destination-patch ; the patch where copy_order has to move
  order-number      ; the who number of the order
]

invoices-own [
  destination-patch ; the patch where the invoice has to go
  order-number      ; the (who) number of the invoice (NetLogo object/turtle)
]

globals [
  working-time      ; a variable to check working hours (about 9 hours between 9 to 18 every day): "night", "wt-morning", "lunch-time", "wt-afternoon"
  ; variables related to time
  day minute hour

  ; monitors variables
  orders-created
  count-payement
  IS-monit
  avgCycleTime
  avgWorkedTime
]

turtles-own [ moving? ]  ; every turtle
patches-own [ pname ]    ; the name of the patch (PO,V,R,AP,IS)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                                            SETUP                                                 ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup  ;; setup procedures are in setup.nls
  ca
  setup-patches
  setup-hr
  setup-variables
  reset-ticks
  setup_csv
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                                       GO - MAIN  CYCLE                                           ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  tick                    ; each tick correponds to one minute (60 ticks = 1 hour, 9:00 correponds to 540 ticks,  18 hours is 1080 ticks)
  if ticks = 6840 [compute-avgServiceTime stop]  ; T = 60 x 24 = 1440 = 1 day; 5 working days = 7200 (6839); 4 weeks = 28800 (28439); stop condition T - (60m * 6h - 1) => T - 361
  arrivalOfOrders         ; orders arrive [when working hours is ok]
  check-workers           ; workers free start serve an order
  check-moving            ; turtle moving on the screen
  check-time              ; check if order or worker end their period
  pass-time               ; the passage of time
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                                        SETUP procedures                                          ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-patches
  ask patches [ set pcolor 4 ]
  ask patches with [(pxcor > -14 and pxcor < -5) and (pycor > 9 and pycor < 14)][ set pcolor red set pname "PO" ]    ; PURCHASING OFFICE
  ask patches with [(pxcor > 5 and pxcor < 14) and (pycor > 9 and pycor < 14)][ set pcolor gray set pname "V" ]      ; VENDOR
  ask patches with [(pxcor > -4 and pxcor < 4) and (pycor > 1 and pycor < 7)][ set pcolor blue set pname "R" ]       ; RECEIVINGS
  ask patches with [(pxcor > -6 and pxcor < 6) and (pycor > -10 and pycor < -5)][ set pcolor green set pname "AP" ]  ; ACCOUNTS PAYABLE

  setup-label

  if use-case = "Mazda"  ;; add IS for use-case "Mazda"
    [
      ask patches with [(pxcor > -14 and pxcor < -8) and (pycor > -3 and pycor < 3)][ set pcolor pink set pname "IS"]
      ask patches with [pxcor = -9 and pycor = 3 ] [ set plabel "INF.SYSTEM" ]
    ]
end

to setup-label
  ask patches with [pxcor = -7 and pycor = 14 ] [set plabel "PURCHASING"]      ; just labels
  ask patches with [pxcor = 10 and pycor = 14 ] [set plabel "VENDOR"]
  ask patches with [pxcor = 2 and pycor = 7 ] [set plabel "RECEIVING"]
  ask patches with [pxcor = 4 and pycor = -5] [set plabel "ACCOUNTS PAYABLE"]
end

to setup-hr
  create-workers n-workers
    [ ; place  workers on the view
      set shape "dot" set color 58
      setxy (16 - random 33) (-13 - random 4)
      fd random-float 1
      ; initialise variables
      set state-worker "waiting"  ;
      set moving? false           ; workers never move, just change their color according to their state
      set service-time 0
      set duration -1
    ]
end

to setup-variables
  set working-time "night"
  set count-payement 0
  set IS-monit 0
  set minute 0
  set hour 0
  set day 1
  set avgCycleTime 0
  set avgWorkedTime 0
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                                          GO procedures                                           ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to arrivalOfOrders  ; a certain amount of orders arrive every tot minutes, waiting for an operator to work ;
  if working-time = "wt-morning" or working-time = "wt-afternoon" and ticks mod 15 = 0    ; every 15 minutes...
    [
      set orders-created orders-created + n-orders
      create-orders n-orders   ; ... a new set/bunch of n orders (as defined by n-of-order slider) arrive in the sim.
      [
        set size 0.6 set shape "dot"
        move-to one-of patches with [ pname = "PO" ]

        set moving? false
        set state-order "waiting-for-worker"  ; the new order has an initial state "waiting-for-worker"

        set order-arrival-time ticks      ; set the order-arrival-time

        set my_copy_order_arrived? false  ;
        set my_invoice_arrived? false     ;
      ]
   ]
end

to check-workers  ; worker  "waiting" and not moving: agent starts working on the waiting orders
  ifelse working-time = "wt-morning" or working-time = "wt-afternoon" [
    if any? workers with [state-worker = "waiting"] and any? orders with [state-order = "waiting-for-worker"]
    [
      ask workers with [state-worker = "waiting" ]
      [
        output_csv ; for data recording
        let orders-waiting orders with [state-order = "waiting-for-worker"]
        if any? orders-waiting
          [
            let select-an-order one-of orders-waiting  ;; select an order to serve
            set working-with select-an-order

            let d compute-duration self                ;; define the duration of the task
            set duration d

            ask select-an-order
              [
                output_csv ; for data recording
                set state-order "service"
                set working-with myself

                if [pname] of patch-here = "PO" ;; emploiees in (P) Ford office send a copy of the order to (AP)
                  [
                    hatch-copy_orders 1
                      [
                        set shape "dot" set size 0.5
                        set order-number myself
                        set moving? true

                        ; define the destination of the agent/copy_order
                        let dest ""
                        if use-case = "Ford" [ set dest one-of patches with [ pname = "AP" ] ] ;
                        if use-case = "Mazda" [ set dest one-of patches with [pname = "IS"] set IS-monit IS-monit + 1] ;

                        set heading towards dest
                        set destination-patch dest
                      ]
                  ]
              ]
            set state-worker "service"
            set service-time service-time + duration
            set color red
          ]
        ]
      ]
    ]
    [ ; a trick to avoid unuseful cycles:
      ; check workers: if all workers stopped their work, move to next starting time (9AM or 14AM)
      ifelse working-time = "lunch-time"
        [
          tick-advance ( (1440 * (day - 1) + 840) - ticks - 1 )
          set hour 14 set minute 0
        ][
           if working-time = "night"
             [
               ifelse ticks < 540
                 [ tick-advance (540 - (1440 * (day - 1)) - ticks - 1 )
                 ][
                   set day day + 1
                   tick-advance (540 + (1440 * (day - 1)) - ticks - 1 )
                 ]
               set hour 9 set minute 0
             ]
        ]
     ]
end

to-report compute-duration [a]
  let d 0 ; duration based on the use-case and the pname of state
  ask a
    [
      output_csv ; for data recording
      if [pname] of working-with  = "PO"
        [
          if use-case = "Ford" [ set d 15 + random (31) ] ; 15-45 minutes for a worker to prepare an order + send order to vendor + prepare/send a copy of order to AP
          if use-case = "Mazda" [ set d 3 + random (8) ]  ; 3-10 minutes for a worker to prepare an order + send order to vendor
        ]
      if [pname] of working-with  = "R"
        [
          if use-case = "Ford" [ set d 10 + random (16) ] ; 10-25 minutes to place goods in the warehouse and prepare/send the receipt
          if use-case = "Mazda" [ set d 5 + random (6) ]  ; 5-10 minutes to place goods in the warehouse
        ]
      if [pname] of working-with  = "AP"
        [
          if use-case = "Ford" [ set d 15 + random (31) ]  ; 15-45 minutes (on average) to check invoice + rec doc + send payment
          if use-case = "Mazda" [ set d 1 + random (3) ]   ; 1-3 minutes
        ]
      if [pname] of working-with  = "V" [ set d ticks + 10 ]
    ]
    report d
end

to check-moving
  ask turtles with [moving? = True]
    [
      output_csv ; for data recording
      ifelse patch-here != destination-patch
        [ fd random-float 1 ]
        [
          set moving? false
          if breed = copy_orders
            [
              if use-case = "Ford" [ ask order-number [
              output_csv ; for data recording
              set my_copy_order_arrived? true ]]
              die
            ]
          if breed = invoices
            [
              if use-case = "Ford" [ ask order-number [
              output_csv ; for data recording
              set my_invoice_arrived? true set shape "box"] ]
              die
            ]
          if breed = orders
            [
              set state-order "waiting-for-worker"
              if [pname] of patch-here = "V"
                [
                  set state-order "delay"      ; from 2 hours to ... hours delay  [120 - 720]
                  set duration 10 + random 110 ; time-limit: ticks 10m up to 2h

                  hatch-invoices 1
                    [
                      set order-number myself
                      set moving? true
                      set size 0.6 set shape "star"
                      let dest one-of patches with [pname = "AP"]
                      set heading towards dest
                      set destination-patch dest
                    ]
                ]
            ]
        ]
    ]
end

to check-time

  ; order and worker become not in service after the amount of time working
  if any? orders with [ state-order = "delay" and duration = 0 ]
    [
      ask orders with [ state-order = "delay" and duration = 0 ]
        [
          output_csv ; for data recording
          compute-next-state [pname] of patch-here
          set state-order "moving"
        ]
     ]

  if any? orders with [ state-order = "delay" and duration > 0 ]
    [ ask orders with [ state-order = "delay" and duration > 0 ] [
      output_csv ; for data recording
      set duration duration - 1 ] ]

  if any? workers with [ state-worker = "service" and duration = 0]
    [
      ask workers with [state-worker = "service" and duration = 0]
        [ output_csv ; for data recording
          ifelse working-time = "wt-morning" or working-time = "wt-afternoon"
            [ set state-worker "waiting" set color green ]
            [ set state-worker "not-working-time" set color gray ]

          ask working-with
            [
              output_csv ; for data recording
              compute-next-state [pname] of patch-here
              set state-order "moving"
            ]
        ]
    ]

  if any? workers with [ state-worker = "service" and duration > 0]
    [ ask workers with [state-worker = "service" and duration > 0] [
      output_csv ; for data recording
      set duration duration - 1 ] ]
end

to send-order-to-destination [ d ]
  let dest one-of patches with [pname = d]
  set heading towards dest
  set destination-patch dest
  set moving? true
  set state-order "moving"
end

to computeCycleTime [a]
  set avgCycleTime (avgCycleTime * (count-payement ) + a) / (count-payement + 1)
end

to compute-avgServiceTime
  set avgWorkedTime (sum [service-time] of workers / n-workers) / 2400 * 100
end

to compute-next-state [s]
  if s = "PO" [ send-order-to-destination "V" ]
  if s = "V"  [ send-order-to-destination  "R"]
  if s = "R"
    [
      set state-order "waiting-for-worker"
      send-order-to-destination "AP"
    ]

  if s = "AP"
    [
      ifelse use-case = "Ford"
        [
          if my_invoice_arrived? and my_copy_order_arrived?
            [ computeCycleTime ticks - order-arrival-time
              set count-payement count-payement + 1
              die
            ]
         ][
             set IS-monit IS-monit - 1
             computeCycleTime ticks - order-arrival-time
             set count-payement count-payement + 1
             die
          ]
    ]
end

to restore-workers-service
   if any? workers with [state-worker =  "not-working-time"][
      ask workers with [state-worker =  "not-working-time"][
      output_csv ; for data recording
      set state-worker "waiting" ]]
    if any? workers with [duration > 0 ][
      ask workers with [duration > 0 ][
      output_csv ; for data recording
      set state-worker "service" ]]
end

to pass-time
  ;; start at 9 o'clock
  if hour = 9 and minute = 0
    [
      set working-time "wt-morning"
      restore-workers-service
    ]

  ;; start lunch time of 1 h at 13
  if hour = 13 and minute = 0
    [
      set working-time "lunch-time"
      ask workers [
        output_csv ; for data recording
        set state-worker "not-working-time"]
    ]

  ;; end lunch time - start working at 14
  if hour = 14 and minute = 0
    [
      set working-time "wt-afternoon"
      restore-workers-service
    ]

  if hour = 18 and minute = 0
    [
      set working-time "night"
      ask workers [
        output_csv ; for data recording
        set state-worker "not-working-time"]
    ]

  ; increment time
  ifelse minute < 59 [ set minute minute + 1 ][ set minute 0 set hour hour + 1 ]
  if hour = 24 [ set hour 0  set day day + 1 compute-avgServiceTime ]
end

to setup_csv
  file-open "process_temp.csv"
  file-print csv:to-row (list "ticks" "breed" "who" "state-order" "time-limit" "working-with" "duration" "destination-patch" "my_invoice_arrived?" "my_copy_order_arrived?" "order-arrival-time" "working-time")
  file-close
  file-delete "process_temp.csv"
  file-open "process_temp.csv"
  file-print csv:to-row (list "ticks" "breed" "who" "state-order" "time-limit" "working-with" "duration" "destination-patch" "my_invoice_arrived?" "my_copy_order_arrived?" "order-arrival-time" "working-time")
  file-close
end

to output_csv
  if breed = orders
  [
    file-open "process_temp.csv"
    file-print csv:to-row (list ticks breed who state-order time-limit working-with duration destination-patch my_invoice_arrived? my_copy_order_arrived? order-arrival-time working-time)
    file-close
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
13
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
12
123
67
173
SETUP
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
147
122
202
173
GO
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

MONITOR
217
336
342
381
Orders in the system
count orders
17
1
11

SLIDER
110
78
207
111
n-orders
n-orders
10
100
80.0
5
1
NIL
HORIZONTAL

PLOT
650
10
1414
232
Workers 
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"SERVICE" 1.0 0 -5298144 true "" "if ticks mod 30 = 0[plot count workers with [state-worker = \"service\"]]"
"WAITING" 1.0 0 -5509967 true "" "if ticks mod 30 = 0 [plot count workers with [state-worker = \"waiting\"]]"
"NWT" 1.0 0 -7500403 true "" "if ticks mod 30 = 0 [plot count workers with [state-worker = \"not-working-time\"]]"

MONITOR
519
304
634
349
Completed orders
count-payement
17
1
11

PLOT
650
234
1414
448
Orders
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"SERVICE" 1.0 0 -8053223 true "" "if ticks mod 60 = 0[plot count orders with [state-order = \"service\"]]"
"WAITING" 1.0 0 -5509967 true "" "if ticks mod 60 = 0[plot count orders with [state-order = \"waiting-for-worker\"]]"
"DELAY" 1.0 0 -7500403 true "" "if ticks mod 60 = 0[plot count orders with [state-order = \"delay\"]]"

MONITOR
64
265
116
310
Waiting
count orders with [ state-order = \"waiting-for-worker\"]
17
1
11

MONITOR
54
332
104
377
Waiting
count workers with [ state-worker = \"waiting\"]
17
1
11

BUTTON
84
140
146
173
One step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
3
332
53
377
Service
count workers with [state-worker = \"service\"]
17
1
11

MONITOR
13
197
63
242
NIL
day
17
1
11

SLIDER
5
78
109
111
n-workers
n-workers
100
500
500.0
5
1
NIL
HORIZONTAL

MONITOR
395
154
462
199
Receiving
count orders-on patches with [pcolor = blue]
17
1
11

CHOOSER
110
10
207
55
Use-case
Use-case
"Ford" "Mazda"
0

MONITOR
105
332
208
377
NotWorkingTime
count workers with [ state-worker = \"not-working-time\"]
17
1
11

MONITOR
117
265
167
310
Delay
count orders with [ state-order = \"delay\"]
17
1
11

MONITOR
223
290
335
335
Orders created
orders-created
17
1
11

MONITOR
381
13
469
58
Working Time
working-time
17
1
11

MONITOR
570
160
634
205
In transit
count orders with [state-order = \"moving\"]
17
1
11

TEXTBOX
9
13
88
49
Select use-case:
14
0.0
1

TEXTBOX
9
58
159
76
Initial parameters
14
0.0
1

MONITOR
13
265
63
310
Served
count orders with [state-order = \"service\"]
17
1
11

MONITOR
280
57
330
102
PO
count orders-on patches with [pcolor = 15]
1
1
11

MONITOR
404
304
454
349
AP
count orders-on patches with [pcolor = green]
1
1
11

MONITOR
527
57
577
102
Vendor
count orders-on patches with [pcolor = gray]
17
1
11

TEXTBOX
14
248
149
266
State of the orders
14
0.0
1

MONITOR
260
207
310
252
IS
IS-monit
17
1
11

TEXTBOX
14
315
164
333
State of the workers
14
0.0
1

TEXTBOX
13
180
112
198
Simulation time
14
0.0
1

MONITOR
97
403
209
448
AvgServiceTime(%)
avgWorkedTime
2
1
11

MONITOR
115
197
167
242
NIL
minute
17
1
11

MONITOR
64
197
114
242
NIL
hour
17
1
11

MONITOR
3
403
96
448
AvgCycle-Time
avgCycleTime
1
1
11

TEXTBOX
14
385
164
403
Performance Indicators
14
0.0
1

@#$#@#$#@
## WHAT IS IT?


The model describes the payment processes in two different organisations: Ford and Mazda (before the acquision by Ford in 1979)


In Ford organisation, the main units involved are:
- Purchasing (P): The office with the function of procuring supplies or services by mean of purchase orders.
- Receiving (R): The Department receiving a product from a manufacturer/supplier.
- Accounts Payable (AP): This refers to the business department charged to make payments to suppliers and other creditors. 

The model involves also:
- Vendors (V): They receive an order from (P) and ship both goods to (R) and an invoice to (AP).  

The process in Mazda includes an Information System (IS) to register orders from (P), the arrival of products in (R), and a link to (AP).

The Ford model starts with 500 workers. Each activity has a different duration.

The Mazda model starts with 100 workers doing their service. 

## HOW IT WORKS

The main objects in the business process are:
- 'workers': agents having a state: "service", "waiting", "not working time". They work in office time (every week days, between 9-13 and 14-18).
- 'orders': they arrive in the process in bunch of 'n-of-orders' every 15 minutes. Their corresponding states are "waiting-for-worker" or "working". In addition, they can be in "delay" state (when no other
 "moving".
- 'copy_order' and 'invoice' are sent to AP in Ford process

Workers "waiting" look for a "waiting-for-worker" orders, committing to work with them for a period of time registered by the vaiable "time-limit". This model considers a unit time of 1 ticks = 1 minute.

The process starts with the generation of an orders from P office to Vendor, which also send a copy_order to AP. The conclusion of the process is the check by AP of three conditions: the copy of the order from the purchaising office, the invoice from the vendor, the goods are in the receiving. Once both three conditions are verified, the payment is made to the vendor.


## HOW TO USE IT

Set configuration parameter to simualate Ford Use-case (500 workers) and Mazda use-case (100 workers). 


## THINGS TO NOTICE

In Ford use-case order with invoices has a "box" shape; 

## EXTENDING THE MODEL

Add Performance Indicators, e.g. Waiting-time


## CREDITS AND REFERENCES

ES
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

letter sealed
false
0
Rectangle -7500403 true true 30 90 270 225
Rectangle -16777216 false false 30 90 270 225
Line -16777216 false 270 105 150 180
Line -16777216 false 30 105 150 180
Line -16777216 false 270 225 181 161
Line -16777216 false 30 225 119 161

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experimentFM-5080100-100300500" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 6840</exitCondition>
    <metric>AvgCycleTime</metric>
    <metric>AvgServiceTime</metric>
    <metric>count orders</metric>
    <metric>count-payement</metric>
    <metric>count orders-on patches with [pcolor = 15]</metric>
    <metric>count orders-on patches with [pcolor = 105]</metric>
    <metric>count orders-on patches with [pcolor = 65]</metric>
    <metric>count orders-on patches with [pcolor = 5]</metric>
    <enumeratedValueSet variable="Use-case">
      <value value="&quot;Ford&quot;"/>
      <value value="&quot;Mazda&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-of-orders">
      <value value="50"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-of-workers">
      <value value="100"/>
      <value value="300"/>
      <value value="500"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
