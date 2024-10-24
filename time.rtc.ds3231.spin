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


PUB alarm1_day(d=-2): curr_day
' Set alarm #1 day
'   Valid values: 1..31
'   Any other value returns the current day of the month
    readreg(core.ALM1_DAYDATE, 1, @curr_day)
    case d
        1..31:
            curr_day &= core.ALMX_SET           ' preserve alarm bit
            d := int2bcd(d)                     ' day and weekday alarms share
            d |= curr_day                       ' the same reg; not setting
            writereg(core.ALM1_DAYDATE, 1, @d)  ' bit 6 means this is a day of
        other:                                  '   the month
            return bcd2int(curr_day & core.DATE_MASK)


PUB alarm1_hours(h=-2): curr_hr
' Set alarm #1 hours
'   Valid values: 0..23
'   Any other value returns the current second
    readreg(core.ALM1_HR, 1, @curr_hr)
    case h
        0..23:
            curr_hr &= core.ALMX_SET
            h := int2bcd(h)
            h |= curr_hr
            writereg(core.ALM1_HR, 1, @h)
        other:
            return bcd2int(curr_hr & core.HOURS_MASK)


PUB alarm1_minutes(m=-2): curr_min
' Set alarm #1 minutes
'   Valid values: 0..59
'   Any other value returns the current second
    readreg(core.ALM1_MIN, 1, @curr_min)
    case m
        0..59:
            curr_min &= core.ALMX_SET           ' isolate the alarm bit
            m := int2bcd(m)
            m |= curr_min                       ' preserve alarm bit
            writereg(core.ALM1_MIN, 1, @m)
        other:
            return bcd2int(curr_min & core.MINUTES_MASK)


PUB alarm1_rate(rate=-2): curr_rate | a1m[4], tmp
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
                readreg(core.ALM1_SEC + tmp, 1, @a1m[tmp])
                if (tmp == 3)                   ' if this is the day/date reg,
                    a1m[tmp] &= core.DYDT_MASK  '   clear day/date bit (= date)
                a1m[tmp] &= core.ALMX_MASK      ' clear the existing A1Mx bit

                ' update the alarm bit and write the updated reg. back
                a1m[tmp] |= ((rate >> tmp) & 1) << core.ALMX
                writereg(core.ALM1_SEC + tmp, 1, @a1m[tmp])
        16:
            repeat tmp from 0 to 3
                readreg(core.ALM1_SEC + tmp, 1, @a1m[tmp])
                if (tmp == 3)
                    a1m[tmp] |= core.ALM_DAY    ' set day/date bit (= day)
                a1m[tmp] &= core.ALMX_MASK      ' clear the existing A1Mx bit
                a1m[tmp] |= (((rate >> tmp) & 1)) << core.ALMX
                writereg(core.ALM1_SEC + tmp, 1, @a1m[tmp])
        other:
            repeat tmp from 0 to 3
                readreg(core.ALM1_SEC + tmp, 1, @a1m[tmp])
                curr_rate |= ((a1m[tmp] >> core.ALMX) & 1) << tmp
            curr_rate |= ((a1m[3] >> core.DYDT) & 1) << 4


PUB alarm1_seconds(s=-2): curr_sec
' Set alarm #1 seconds
'   Valid values: 0..59
'   Any other value returns the current second
    readreg(core.ALM1_SEC, 1, @curr_sec)
    case s
        0..59:
            curr_sec &= core.ALMX_SET           ' preserve alarm bit
            s := int2bcd(s)
            s |= curr_sec
            writereg(core.ALM1_SEC, 1, @s)
        other:
            return bcd2int(curr_sec & core.SECONDS_MASK)


PUB alarm1_wkday(d=-2): curr_wkday
' Set alarm #1 week day
'   Valid values: 1..7
'   Any other value returns the current week day
    readreg(core.ALM1_DAYDATE, 1, @curr_wkday)
    case d
        1..7:
            curr_wkday &= core.ALMX_SET         ' preserve alarm bit
            d := int2bcd(d)                     ' day and weekday alarms share
            d |= core.ALM_DAY                   ' the same reg; indicate this
            d |= curr_wkday                     ' preserve alarm bit
            writereg(core.ALM1_DAYDATE, 1, @d)  ' is a weekday
        other:
            return bcd2int(curr_wkday & core.DAY_MASK)


PUB clk_data_ok(): flag
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
    return (_clkdata_ok == 0)


PUB clkout_freq(freq=-2): curr_freq
' Set frequency of SQW pin, in Hz
'   Valid values: 0, 1, 1024, 4096, 8192
'   Any other value polls the chip and returns the current setting
    curr_freq := 0
    readreg(core.CONTROL, 1, @curr_freq)
    case freq
        0:
            freq |= (1 << core.INTCN)           ' turn on interrupt output
            freq := (curr_freq & core.BBSQW_MASK)   ' Turn off clock output
        1, 1024, 4096, 8192:
            curr_freq &= core.INTCN_MASK        ' turn off interrupt output
            freq := lookdownz(freq: 1, 1024, 4096, 8192) << core.RS
            freq |= (1 << core.BBSQW)           ' turn on clock output
        other:
            case (curr_freq >> core.BBSQW) & 1
                0:                              ' if square wave output is
                    return 0                    ' disabled, return 0
                1:
                    curr_freq := (curr_freq >> core.RS) & core.RS_BITS
                    return lookupz(curr_freq: 1, 1024, 4096, 8192)

    freq := ((curr_freq & core.RS_MASK) | freq)
    writereg(core.CONTROL, 1, @freq)


PUB int_clear(mask) | tmp
' Clear asserted interrupts
    tmp := 0
    readreg(core.CTRL_STAT, 1, @tmp)
    case mask
        %00..%11:                               ' ints clear
            mask ^= core.AXF_BITS               ' ints clear when bits cleared
            tmp := ((tmp & core.AXF_MASK) | tmp)
            writereg(core.CTRL_STAT, 1, @tmp)
        other:
            return


PUB interrupt(): mask
' Mask indicating one or more interrupts are asserted
    readreg(core.CTRL_STAT, 1, @mask)
    return (mask & core.AXF_BITS)


PUB int_mask(mask=-2): curr_mask
' Set interrupt mask
'   Bits %10
'       1: Alarm 2 interrupt enable
'       0: Alarm 1 interrupt enable
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core.CONTROL, 1, @curr_mask)
    case mask
        %00..%11:
            mask := ((curr_mask & core.AIE_MASK) | mask)
            writereg(core.CONTROL, 1, @mask)
        other:
            return (curr_mask & core.AIE_MASK)


PUB osc_ena(state=-2): curr_state
' Enable the on-chip oscillator
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: This setting only takes effect when the RTC is powered
'       by Vbat. When powered by Vcc, the oscillator is always on
    curr_state := 0
    readreg(core.CONTROL, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core.EOSC
            state := ((curr_state & core.EOSC_MASK) | state)
            writereg(core.CONTROL, 1, @state)
        other:
            return (((curr_state >> core.EOSC) & 1) == 1)


PUB osc_offset(): curr_offs
' Get oscillator aging offset
'   Returns: 100's of ppb
    curr_offs := 0
    readreg(core.AGE_OFFS, 1, @curr_offs)
    return ~curr_offs


PUB osc_set_offset(offs)
' Set oscillator aging offset, in 100's of ppb
'   Valid values: -128 to 127 (clamped to range)
'   NOTE: This setting is specified at an ambient temperature of +25C, typical
'   NOTE: The effects of this setting can be observed at the 32kHz output. To effect changes
'       immediately, trigger a temperature conversion using temp_measure()
    offs := (-128 #> offs <# 127)
    writereg(core.AGE_OFFS, 1, @offs)


PUB poll_rtc()
' Read the time data from the RTC and store it in hub RAM
    readreg(core.SECONDS, 7, @_secs)
    readreg(core.CTRL_STAT, 1, @_clkdata_ok)
    _clkdata_ok := (_clkdata_ok >> core.OSF) & 1
    _secs &= core.SECONDS_MASK
    _mins &= core.MINUTES_MASK
    _hours &= core.HOURS_MASK
    _days &= core.DATE_MASK
    _wkdays &= core.DAY_MASK
    _months &= core.MONTH_MASK
    _years &= core.YEAR_MASK


PUB reset() | tmp
' Reset the device
'   NOTE: This is used to clear the oscillator stopped flag, readable using
'       clk_data_ok()
    tmp := 0
    readreg(core.CTRL_STAT, 1, @tmp)
    tmp &= core.OSF_MASK                        ' turn off the
    writereg(core.CTRL_STAT, 1, @tmp)           '   "oscillator-stopped" flag


PUB set_date(d)
' Set day of month
'   Valid values: 1..31
'   Any other value is ignored
    d := int2bcd(1 #> d <# 31)
    writereg(core.DATE, 1, @d)


PUB set_hours(h)
' Set hours
'   Valid values: 0..23
'   Any other value is ignored
    h := int2bcd(0 #> h <# 23)
    writereg(core.HOURS, 1, @h)


PUB set_minutes(m)
' Set minutes
'   Valid values: 0..59
'   Any other value is ignored
    m := int2bcd(0 #> m <# 59)
    writereg(core.MINUTES, 1, @m)


PUB set_month(m)
' Set month
'   Valid values: 1..12
'   Any other value is ignored
    m := int2bcd(1 #> m <# 12)
    writereg(core.MONTH, 1, @m)


PUB set_seconds(s)
' Set seconds
'   Valid values: 0..59
'   Any other value is ignored
    s := int2bcd(0 #> s <# 59)
    writereg(core.SECONDS, 1, @s)


PUB set_weekday(w)
' Set day of week
'   Valid values: 1..7
'   Any other value is ignored
    w := int2bcd(1 #> (w-1) <# 7)
    writereg(core.DAY, 1, @w)


PUB set_year(y)
' Set 2-digit year
'   Valid values: 0..99
'   Any other value is ignored
    y := int2bcd(0 #> y <# 99)
    writereg(core.YEAR, 1, @y)


PUB temp_data(): temp
' Temperature ADC data
    temp := 0
    readreg(core.TEMP_MSB, 2, @temp)


PUB temp_data_rdy(): flag
' Flag indicating temperature data ready
    flag := 0
    readreg(core.CTRL_STAT, 1, @flag)
    return (((flag >> core.BSY) & 1) == 0)


PUB temp_measure() | tmp, meas
' Perform a manual temperature measurement
'   NOTE: The RTC automatically performs temperature measurements
'       every 64 seconds
    tmp := 0
    readreg(core.CONTROL, 1, @tmp)
    tmp |= (1 << core.CONV)                     ' set bit to trigger measurement

    writereg(core.CONTROL, 1, @tmp)


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


PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from device into ptr_buff
    case reg_nr
        core.SECONDS..core.TEMP_MSB:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start()
            i2c.write(SLAVE_RD)
            if (reg_nr == core.TEMP_MSB)
                i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c.NAK)
            else
                i2c.rdblock_lsbf(ptr_buff, nr_bytes, i2c.NAK)
            i2c.stop()
        other:
            return


PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to device from ptr_buff
    case reg_nr
        core.SECONDS..core.AGE_OFFS:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_lsbf(ptr_buff, nr_bytes)
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

