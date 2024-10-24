{
----------------------------------------------------------------------------------------------------
    Filename:       DS3231-Demo.spin
    Description:    Demo of the DS3231 driver
        * Time/Date output
    Author:         Jesse Burt
    Started:        Nov 18, 2020
    Updated:        Oct 17, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode = xtal1+pll16x
    _xinfreq = 5_000_000


OBJ

    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    rtc:    "time.rtc.ds3231" | SCL=28, SDA=29, I2C_FREQ=100_000


PUB main() | wkday, month, date, yr

    setup()
' Uncomment below to set date/time
'   (only needs to be done once as long as RTC remains powered afterwards)
'   The time object contains symbols that can be used in place of integers for the month or
'       day of the week (e.g., time.OCT, time.OCTOBER, time.TUE, time.TUESDAY
'                 hh, mm, ss, MMM, DD, WKDAY, YY
'    set_date_time(07, 10, 00, time.OCT, 15, time.TUE, 24)

    repeat
        rtc.poll_rtc()
        { get weekday and month name strings from DAT table below }
        wkday := @wkday_name[(rtc.weekday() - 1) * 4]
        month := @month_name[(rtc.month() - 1) * 4]
        date := rtc.date()
        yr := rtc.year()

        ser.pos_xy(0, 3)
        ser.str(wkday)
        ser.printf3(@" %d %s 20%d ", date, month, yr)
        ser.printf3(@"%02.2d:%02.2d:%02.2d", rtc.hours(), rtc.minutes, rtc.seconds())


PUB set_date_time(h, m, s, mmm, dd, wkday, yy)
' Update RTC's time
    rtc.set_hours(h)                             ' 00..23
    rtc.set_minutes(m)                           ' 00..59
    rtc.set_seconds(s)                           ' 00..59

    rtc.set_month(mmm)                           ' 01..12
    rtc.set_date(dd)                             ' 01..31
    rtc.set_weekday(wkday)                       ' 01..07
    rtc.set_year(yy)                             ' 00..99


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( rtc.start() )
        ser.strln(@"DS3231 driver started")
    else
        ser.strln(@"DS3231 driver failed to start - halting")
        repeat


DAT
    { map numbers to weekday and month names }
    wkday_name
        byte    "Sun", 0                        ' 1
        byte    "Mon", 0
        byte    "Tue", 0
        byte    "Wed", 0
        byte    "Thu", 0
        byte    "Fri", 0
        byte    "Sat", 0                        ' 7

    month_name
        byte    "Jan", 0                        ' 1
        byte    "Feb", 0
        byte    "Mar", 0
        byte    "Apr", 0
        byte    "May", 0
        byte    "Jun", 0
        byte    "Jul", 0
        byte    "Aug", 0
        byte    "Sep", 0
        byte    "Oct", 0
        byte    "Nov", 0
        byte    "Dec", 0                        ' 12


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

