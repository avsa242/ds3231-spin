# ds3231-spin 
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the DS3231 Real-Time Clock.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.


## Salient Features

* I2C connection at up to 400kHz
* Read and set days, hours, months, minutes, seconds, weekday, year (individually)
* Read on-chip temperature sensor
* Get/set alarm date/times, repetition
* Get/set oscillator aging offset


## Requirements

P1/SPIN1:
* 1 extra core/cog for the PASM I2C engine (none if bytecode engine is used)
* sensor.temp.common.spinh (provided by spin-standard-library)
* time.rtc.common.spinh (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* sensor.temp.common.spin2h (provided by p2-spin-standard-library)
* time.rtc.common.spin2h (provided by p2-spin-standard-library)


## Programming interface

See the [spin1 time API](https://github.com/avsa242/spin-standard-library/tree/testing/api/time.md)
or [spin2 time API](https://github.com/avsa242/p2-spin-standard-library/tree/testing/api/time.md)


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (6.9.4)       | NuCode       | Untested              |
| P2        | SPIN2    | FlexSpin (6.9.4)       | Native/PASM2 | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* TBD

