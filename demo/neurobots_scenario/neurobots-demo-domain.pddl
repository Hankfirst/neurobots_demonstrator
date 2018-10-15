(define (domain neurobots-demo)
  (:requirements :adl :object-fluents)
  (:types
   furniture robot human - base
   bottle cup - vessel
   content
   room
   )

  (:constants
   empty - content
   nowhere - base
   )

  (:predicates
   (connected ?l1 ?l2 - room)
   (is-open ?v - vessel)
   (arm-empty ?r - robot)
   (mobile ?r - robot) ;; only mobile robots can move around
   (has-drunk ?h - human ?c - content)
   )

  (:functions
   (position ?v - vessel) - base
   (at ?r - robot) - base
   (in ?b - base) - room
   (contains ?v - vessel) - content
  )

  (:action grasp
           :parameters (?rob - robot ?v - vessel ?b - base)
           :precondition (and (= (at ?rob) ?b)
                              (= (position ?v) ?b)
                              (arm-empty ?rob)
                              )
           :effect (and (assign (position ?v) ?rob)
                        (not (arm-empty ?rob))))


  (:action go
           :parameters (?r - robot ?from ?to - room ?oldbase - base)
           :precondition (and (= (in ?r) ?from)
                              (= (at ?r) ?oldbase)
                              (mobile ?r)
                              (connected ?from ?to))
           :effect (and (assign (in ?r) ?to)
                        (assign (at ?r) nowhere)
                        ))

  (:action approach
           :parameters (?rb - robot ?rm - room ?bs ?oldbase - base)
           :precondition (and (= (in ?rb) ?rm)
                              (= (in ?bs) ?rm)
                              (= (at ?rb) ?oldbase)
                              )
           :effect (and (assign (at ?rb) ?bs)))

  (:action open
           :parameters (?r1 ?r2 - robot ?b - bottle ?f - furniture)
           :precondition (and (= (position ?b) ?r1)
                              (= (at ?r1) ?f)
                              (= (at ?r2) ?f)
                              (arm-empty ?r2)
                              (not (is-open ?b)))
           :effect (and (is-open ?b))
           )

  (:action drop
           :parameters (?dropper - robot ?v - vessel ?fu - furniture)
           :precondition (and (= (position ?v) ?dropper)
                              (= (at ?dropper) ?fu)
                              )
           :effect (and (assign (position ?v) ?fu)
                        (arm-empty ?dropper)))

  (:action drink
           :parameters (?drinkassistant - robot ?h - human ?glass - cup ?c - content)
           :precondition (and (= (at ?drinkassistant) ?h)
                              (= (position ?glass) ?drinkassistant)
                              (= (contains ?glass) ?c)
                              (not (= ?c empty))
                              )
           :effect (and (assign (contains ?glass) empty)
                        (has-drunk ?h ?c)
                        ))

  (:action pour
           :parameters (?rob - robot ?o1 ?o2 - vessel ?f - furniture ?c - content)
           :precondition (and (= (position ?o1) ?rob)
                              (= (position ?o2) ?f)
                              (= (at ?rob) ?f)
                              (is-open ?o1)
                              (is-open ?o2)
                              (= (contains ?o1) ?c)
                              (= (contains ?o2) empty)
                              )
           :effect (and (assign (contains ?o2) ?c)
                        (assign (contains ?o1) empty)
                        ))
)
