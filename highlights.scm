;; highlights.scm - Syntax highlighting queries for Stim
;; Matches actual grammar nodes only

;; Comments
(comment) @comment

;; Measurement instructions
(measurement_instruction) @function.call

;; Detector and Observable instructions
(detector_instruction) @function.builtin
(observable_instruction) @function.builtin

;; Record references
(record_ref) @variable.builtin
(standalone_record_ref) @variable.builtin

;; Gate instructions with different colors for gate types
(gate_instruction
  (gate_name) @keyword.operator)

;; Control flow
(tick) @keyword.control
(repeat_block) @keyword.control.repeat

;; Coordinates and structure
(qubit_coords) @keyword.function
(coords) @number.float

;; Targets
(target
  (integer) @number)
(target
  (underscore) @constant.builtin)

;; Numbers
(integer) @number
(negative_integer) @number.float
(number) @number.float

;; Additional context highlighting
(measurement_instruction
  (target) @parameter)

(detector_instruction
  (record_ref) @variable.parameter)

(repeat_block
  (integer) @number.float)