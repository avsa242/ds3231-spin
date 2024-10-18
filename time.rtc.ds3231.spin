{
----------------------------------------------------------------------------------------------------
    Filename:       time.rtc.ds3231.spin
    Description:    Driver for the DS3231 Real-Time Clock
    Author:         Jesse Burt
    Started:        Nov 17, 2020
    Updated:        Oct 17, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "time.rtc.common.spinh"                ' use code common to all RTC
#include "sensor.temp.common.spinh"             '   and temperature sensor drivers

CON

    { default I/O settings; these can be overridden in the parent object }
    SCL             = 28
    SDA             = 29
    I2C_FREQ        = 100_000
    I2C_ADDR        = 0


    SLAVE_WR        = core.SLAVE_ADDR
    SLAVE_RD        = core.SLAVE_ADDR|1
    I2C_MAX_FREQ    = core.I2C_MAX_FREQ

    { alarm1_rate() settings }
    ALM_1HZ         = 15
    ALM_SS          = 14
    ALM_MMSS        = 12
    ALM_HHMMSS      = 8
    ALM_DDHHMMSS    = 0
    ALM_WKDHHMMSS   = 16


VAR

    byte _secs, _mins, _hours                   ' Vars to hold time
    byte _wkdays, _days, _months, _years        ' Order is important!
    byte _clkdata_ok


OBJ

#ifdef DS3231_SPIN
    i2c:    "com.i2c.nocog"                     ' SPIN I2C engine (~30kHz)
#else
    i2c:    "com.i2c"                           ' PASM I2C engine (~400kHz)
#endif
    core:   "core.con.ds3231"                   ' HW-specific constants
    time:   "time"                              ' timekeeping methods


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 400_000 but is unenforced)
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.TPOR)              ' wait for device startup
            if ( i2c.present(SLAVE_WR) )        ' test device bus presence
                return status
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()
    bytefill(@_secs, 0, 8)


PUB defaults()
' Set factory defaults


PUB alarm1_day(d=-2): c
' Set alarm #1 day
'   Valid values: 1..31
'   Any other value returns the current day of the month
    c := readreg(core.ALM1_DAYDATE)
    case d
        1..31:
            ' preserve alarm bit; day and weekday alarms share the same reg; not setting
            '   bit 6 means this is a day of the month
            writereg(core.ALM1_DAYDATE, int2bcd(d) | (c & core.ALMX_SET) )
        other:
            return bcd2int(c & core.DATE_MASK)


PUB alarm1_hours(h=-2): c
' Set alarm #1 hours
'   Valid values: 0..23
'   Any other value returns the current second
    c := readreg(core.ALM1_HR)
    case h
        0..23:
            writereg(core.ALM1_HR, (c & core.ALMX_SET) | int2bcd(h) )
        other:
            return bcd2int(c & core.HOURS_MASK)


PUB alarm1_minutes(m=-2): c
' Set alarm #1 minutes
'   Valid values: 0..59
'   Any other value returns the current second
    c := readreg(core.ALM1_MIN)
    case m
        0..59:
            writereg(core.ALM1_MIN,  (c & core.ALMX_SET) | int2bcd(m) )
        other:
            return bcd2int(c & core.MINUTES_MASK)


PUB alarm1_rate(rate=-2): c | a1m[4], tmp
' Rate of alarm repetition
'   Valid values:
'       ALM_1HZ(15): alarm once per second
'       ALM_SS(14): when seconds match
'       ALM_MMSS(12): when minutes and seconds match
'       ALM_HHMMSS(8): when hours, minutes and seconds match
'       ALM_DDHHMMSS(0): when date, hours, minutes and seconds match
'       ALM_WKDHHMMSS(16): when weekday, hours, minutes and seconds match
    longfill(@a1m, 0, 5)
    case rate
        0, 8, 12, 14, 15:
            ' The MSB of each alarm reg (seconds .. day/date) forms part of a
            '   5-bit alarm repetition setting. The 5th bit is the day/date bit
            ' Read in each alarm reg, set or clear the repetition bit/MSB based
            '   on the rate this method was called with
            repeat tmp from 0 to 3
                a1m[tmp] := readreg(core.ALM1_SEC + tmp)
                if ( tmp == 3 )                 ' if this is the day/date reg,
                    a1m[tmp] &= core.DYDT_MASK  '   clear day/date bit (= date)
                a1m[tmp] &= core.ALMX_MASK      ' clear the existing A1Mx bit

                ' update the alarm bit and write the updated reg. back
                a1m[tmp] |= ((rate >> tmp) & 1) << core.ALMX
                writereg(core.ALM1_SEC + tmp, a1m[tmp])
        16:
            repeat tmp from 0 to 3
                a1m[tmp] := readreg(core.ALM1_SEC + tmp)
                if ( tmp == 3 )
                    a1m[tmp] |= core.ALM_DAY    ' set day/date bit (= day)
                a1m[tmp] &= core.ALMX_MASK      ' clear the existing A1Mx bit
                a1m[tmp] |= (((rate >> tmp) & 1)) << core.ALMX
                writereg(core.ALM1_SEC + tmp, a1m[tmp])
        other:
            repeat tmp from 0 to 3
                a1m[tmp] := readreg(core.ALM1_SEC + tmp)
                c |= ((a1m[tmp] >> core.ALMX) & 1) << tmp
            c |= ((a1m[3] >> core.DYDT) & 1) << 4


PUB alarm1_seconds(s=-2): c
' Set alarm #1 seconds
'   Valid values: 0..59
'   Any other value returns the current second
    c := readreg(core.ALM1_SEC)
    case s
        0..59:
            ' preserve alarm bit
            writereg(core.ALM1_SEC, (c & core.ALMX_SET) | int2bcd(s) )
        other:
            return bcd2int(c & core.SECONDS_MASK)


PUB alarm1_wkday(d=-2): c
' Set alarm #1 week day
'   Valid values: 1..7
'   Any other value returns the current week day
    c := readreg(core.ALM1_DAYDATE)
    case d
        1..7:
            ' preserve alarm bit; day and weekday alarms share the same reg; indicate this is
            '   a weekday
            writereg(core.ALM1_DAYDATE, (c & core.ALMX_SET) | int2bcd(d) | core.ALM_DAY )
        other:
            return bcd2int(c & core.DAY_MASK)


PUB clk_data_ok(): f
' Flag indicating battery voltage ok/clock data integrity ok
'   Returns:
'       TRUE (-1): Clock data integrity guaranteed
'       FALSE (0): Clock data integrity not guaranteed
'   Possible reasons for this flag to be FALSE:
'       1. First power-on
'       2. Vcc and Vbat are too low for the clock to operate
'       3. The oscillator has been manually powered off using osc_ena()
'       4. External influences on the RTC crystal
    poll_rtc()
    return ( _clkdata_ok == 0 )


PUB clkout_freq(freq=-2): c
' Set frequency of SQW pin, in Hz
'   Valid values: 0, 1, 1024, 4096, 8192
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CONTROL)
    case freq
        0:
            ' turn on interrupt output, turn off clock output
            freq := (c & core.BBSQW_MASK) | (1 << core.INTCN)
        1, 1024, 4096, 8192:
            ' turn off interrupt output, turn on clock output
            c &= core.INTCN_MASK
            freq |= (1 << core.BBSQW) | (lookdownz(freq: 1, 1024, 4096, 8192) << core.RS)
        other:
            case (c >> core.BBSQW) & 1
                0:                              ' if square wave output is
                    return 0                    ' disabled, return 0
                1:
                    c := (c >> core.RS) & core.RS_BITS
                    return lookupz(c: 1, 1024, 4096, 8192)

    freq := ((c & core.RS_MASK) | freq)
    writereg(core.CONTROL, freq)


PUB int_clear(mask) | tmp
' Clear asserted interrupts
    tmp := readreg(core.CTRL_STAT)
    case mask
        %00..%11:
            ' cleared bits clear the corresponding interrupts
            tmp := ((tmp & core.AXF_MASK) | (mask ^ core.AXF_BITS) )
            writereg(core.CTRL_STAT, tmp)
        other:
            return


PUB interrupt(): mask
' Mask indicating one or more interrupts are asserted
    return ( readreg(core.CTRL_STAT) & core.AXF_BITS )


PUB int_mask(mask=-2): c
' Set interrupt mask
'   Bits %10
'       1: Alarm 2 interrupt enable
'       0: Alarm 1 interrupt enable
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CONTROL)
    case mask
        %00..%11:
            writereg(core.CONTROL, ((c & core.AIE_MASK) | mask) )
        other:
            return (c & core.AIE_MASK)


PUB osc_ena(state=-2): c
' Enable the on-chip oscillator
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting only takes effect when the RTC is powered
'       by Vbat. When powered by Vcc, the oscillator is always on
    c := readreg(core.CONTROL)
    case ||(state)
        0, 1:
            writereg(core.CONTROL, (c & core.EOSC_MASK) | ( ||(state) << core.EOSC ) )
        other:
            return ( ( (c >> core.EOSC) & 1) == 1)


PUB osc_offset(): c
' Get oscillator aging offset
'   Returns: 100's of ppb
    c := readreg(core.AGE_OFFS)
    return ~c


PUB osc_set_offset(offs)
' Set oscillator aging offset, in 100's of ppb
'   Valid values: -128 to 127 (clamped to range)
'   NOTE: This setting is specified at an ambient temperature of +25C, typical
'   NOTE: The effects of this setting can be observed at the 32kHz output. To effect changes
'       immediately, trigger a temperature conversion using temp_measure()
    writereg(core.AGE_OFFS, (-128 #> offs <# 127) )


PUB poll_rtc()
' Read the time data from the RTC and store it in hub RAM
    i2c.start()
    i2c.write(SLAVE_WR)
    i2c.write(core.SECONDS)
    i2c.start()
    i2c.write(SLAVE_RD)
    i2c.rdblock_lsbf(@_secs, 7, i2c.NAK)
    i2c.stop()

    _clkdata_ok := readreg(core.CTRL_STAT)
    _clkdata_ok := (_clkdata_ok >> core.OSF) & 1


PUB reset()
' Reset the device
'   NOTE: This is used to clear the oscillator stopped flag, readable using clk_data_ok()
    ' read the control reg, clear the 'oscillator stopped' bit, and write it back
    writereg(core.CTRL_STAT, (readreg(core.CTRL_STAT) & core.OSF_MASK) )


PUB set_date(d)
' Set day of month
'   Valid values: 1..31
'   Any other value is ignored
    writereg(core.DATE, int2bcd(1 #> d <# 31) )


PUB set_hours(h)
' Set hours
'   Valid values: 0..23
'   Any other value is ignored
    writereg(core.HOURS, int2bcd(0 #> h <# 23) )


PUB set_minutes(m)
' Set minutes
'   Valid values: 0..59
'   Any other value is ignored
    writereg(core.MINUTES, int2bcd(0 #> m <# 59) )


PUB set_month(m)
' Set month
'   Valid values: 1..12
'   Any other value is ignored
    writereg(core.MONTH, int2bcd(1 #> m <# 12) )


PUB set_seconds(s)
' Set seconds
'   Valid values: 0..59
'   Any other value is ignored
    writereg(core.SECONDS, 1, int2bcd(0 #> s <# 59) )


PUB set_weekday(w)
' Set day of week
'   Valid values: 1..7
'   Any other value is ignored
    writereg(core.DAY, 1, int2bcd(1 #> (w-1) <# 7) )


PUB set_year(y)
' Set 2-digit year
'   Valid values: 0..99
'   Any other value is ignored
    writereg(core.YEAR, 1, int2bcd(0 #> y <# 99) )


PUB temp_data(): t
' Temperature ADC data
    return readreg(core.TEMP_MSB, 2)


PUB temp_data_rdy(): f
' Flag indicating temperature data ready
    return ( ( ( readreg(core.CTRL_STAT) >> core.BSY) & 1) == 0)


PUB temp_measure()
' Perform a manual temperature measurement
'   NOTE: The RTC automatically performs temperature measurements
'       every 64 seconds
    ' trigger the measurements
    writereg(core.CONTROL, readreg(core.CONTROL) | (1 << core.CONV) )


PUB temp_word2deg(temp_word): temp
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    temp := (temp_word >> 6) * 0_25
    case _temp_scale
        C:
            return
        F:
            return ((temp * 90) / 50) + 32_00
        other:
            return FALSE


PRI readreg(reg_nr, nr_bytes=1): v | cmd_pkt
' Read nr_bytes from device into ptr_buff
    v := 0

    cmd_pkt.byte[0] := SLAVE_WR
    cmd_pkt.byte[1] := reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.start()
    i2c.write(SLAVE_RD)
    i2c.rdblock_msbf(@v, nr_bytes, i2c.NAK)
    i2c.stop()


PRI writereg(reg_nr, val, nr_bytes=1) | cmd_pkt
' Write nr_bytes to device from ptr_buff
    case reg_nr
        core.SECONDS..core.AGE_OFFS:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_lsbf(@val, nr_bytes)
            i2c.stop()
        other:
            return


DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

