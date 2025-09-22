// Tree-sitter grammar for Stim circuits
module.exports = grammar({
  name: 'stim',
  extras: $ => [/\s/, $.comment],
  rules: {
    source_file: $ => repeat($._statement),
    _statement: $ => choice(
      $.measurement_instruction,
      $.detector_instruction,
      $.observable_instruction,
      $.gate_instruction,
      $.qubit_coords,
      $.tick,
      $.repeat_block,
      $.standalone_record_ref,
      $.comment,
      $._newline,
    ),
    measurement_instruction: $ => seq(
      choice('M', 'MR', 'MRX', 'MRY', 'MRZ', 'MX', 'MY', 'MZ'),
      repeat1($.target)
    ),
    detector_instruction: $ => prec.right(seq(
      'DETECTOR',
      optional($.coords),
      repeat1($.record_ref)
    )),
    observable_instruction: $ => prec.right(seq(
      'OBSERVABLE_INCLUDE',
      optional($.coords),
      repeat1($.record_ref)
    )),
    gate_instruction: $ => seq(
      $.gate_name,
      repeat1($.target)
    ),
    gate_name: $ => choice(
      'H', 'X', 'Y', 'Z', 'S', 'S_DAG',
      'SQRT_X', 'SQRT_X_DAG', 'SQRT_Y', 'SQRT_Y_DAG', 'SQRT_Z', 'SQRT_Z_DAG',
      'I', 'CX', 'CY', 'CZ', 'CNOT', 'SWAP', 'ISWAP', 'ISWAP_DAG',
      'XCX', 'XCY', 'XCZ', 'YCX', 'YCY', 'YCZ', 'ZCX', 'ZCY', 'ZCZ',
      'R', 'RX', 'RY', 'RZ',
      'X_ERROR', 'Y_ERROR', 'Z_ERROR',
      'PAULI_CHANNEL_1', 'PAULI_CHANNEL_2',
      'DEPOLARIZE1', 'DEPOLARIZE2',
      'E', 'ELSE_CORRELATED_ERROR', 'MPAD',
    ),
    qubit_coords: $ => seq(
      'QUBIT_COORDS',
      $.coords,
      $.integer
    ),
    tick: $ => 'TICK',
    repeat_block: $ => seq(
      'REPEAT',
      $.integer,
      '{',
      repeat($._statement),
      '}'
    ),
    target: $ => choice(
      $.integer,
      $.underscore,
      seq($.integer, ':', $.integer),
    ),
    record_ref: $ => seq(
      'rec[',
      choice($.integer, $.negative_integer),
      ']'
    ),
    standalone_record_ref: $ => seq(
      'rec[',
      choice($.integer, $.negative_integer),
      ']'
    ),
    coords: $ => seq(
      '(',
      $.number,
      repeat(seq(',', $.number)),
      ')'
    ),
    integer: $ => /\d+/,
    negative_integer: $ => /-\d+/,
    number: $ => choice(
      /\d+/, /-\d+/, /\d+\.\d*/, /-\d+\.\d*/, /\d*\.\d+/, /-\d*\.\d+/,
    ),
    underscore: $ => '_',
    comment: $ => /#.*/,
    _newline: $ => '\n',
  }
});
