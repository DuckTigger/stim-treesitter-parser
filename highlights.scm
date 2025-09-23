;; highlights.scm - Syntax highlighting queries for Stim
;; Matches actual grammar nodes only

;; Comments
(comment) @comment

;; Measurement instructions
(measurement_instruction) @function.call

;; Detector and Observable instructions
(detector_instruction) @type.builtin
(observable_instruction) @type.builtin

;; Record references
(record_ref) @variable.builtin
(standalone_record_ref) @variable.builtin

;; Gate instructions
(gate_instruction
  (gate_name) @function.method)

;; Noise channels
(noise_channel
  (noise_name) @keyword.operator)

;; Control flow
(tick) @type.builtin
(repeat_block) @keyword.control.repeat

;; Coordinates and structure
(qubit_coords) @type.builtin
(shift_coords) @type.builtin
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
