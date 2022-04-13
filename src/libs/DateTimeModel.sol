pragma solidity ^0.5.0;

library DateTimeModel {
    uint64 internal constant YEAR_IN_SECOND = 31536000;
    uint64 internal constant LEAP_YEAR_IN_SECOND = 31622400;
    uint64 internal constant DAY_IN_SECOND = 86400;
    uint64 internal constant HOUR_IN_SECOND = 3600;
    uint64 internal constant MINUTE_IN_SECOND = 60;

    uint16 internal constant START_YEAR = 1970;

    struct DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
    }

    /// @dev a year is a leap year if:
    /// - It is divisible by 4
    /// - Years that are divisible by 100 cannot be a leap year unless they are also divisible by 400
    function isLeapYear(uint256 year) internal pure returns (bool) {
        return year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
    }

    /// @dev a year is a leap year if:
    /// - It is divisible by 4
    /// - Years that are divisible by 100 cannot be a leap year unless they are also divisible by 400
    function getTotalLeapYearBefore(uint256 year) internal pure returns (uint16) {
        year -= 1;
        return uint16(year / 4 + year / 400 - year / 100);
    }

    function getYear(uint64 timeStamp) internal pure returns (uint16) {
        uint256 year = START_YEAR + timeStamp / YEAR_IN_SECOND;
        uint256 totalLeapYears = getTotalLeapYearBefore(year) -
            getTotalLeapYearBefore(START_YEAR);

        uint256 totalSeconds = YEAR_IN_SECOND *
            (year - START_YEAR - totalLeapYears) +
            LEAP_YEAR_IN_SECOND *
            totalLeapYears;

        while (totalSeconds > timeStamp) {
            if (isLeapYear(year - 1)) {
                totalSeconds -= LEAP_YEAR_IN_SECOND;
            } else {
                totalSeconds -= YEAR_IN_SECOND;
            }
            year -= 1;
        }
        return uint16(year);
    }

    function getDaysInMonth(uint8 month, uint256 year)
        internal
        pure
        returns (uint8)
    {
        if (month == 2) {
            if (isLeapYear(year)) return 29;
            return 28;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else {
            return 31;
        }
    }

    function getHour(uint64 timeStamp) internal pure returns (uint8) {
        return uint8((timeStamp / 3600) % 24);
    }

    function getMinute(uint64 timeStamp) internal pure returns (uint8) {
        return uint8((timeStamp / 60) % 60);
    }

    function getSecond(uint64 timeStamp) internal pure returns (uint8) {
        return uint8(timeStamp % 60);
    }

    function toTimeStamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour,
        uint8 minute,
        uint8 second
    ) internal pure returns (uint64 timeStamp) {
        timeStamp = second;
        timeStamp += MINUTE_IN_SECOND * (minute);
        timeStamp += HOUR_IN_SECOND * (hour);
        timeStamp += DAY_IN_SECOND * (day - 1);

        uint16 i;
        for (i = START_YEAR; i < year; i++) {
            if (isLeapYear(i)) {
                timeStamp += LEAP_YEAR_IN_SECOND;
            } else {
                timeStamp += YEAR_IN_SECOND;
            }
        }

        uint8[12] memory monthDayCounts;
        monthDayCounts[0] = 31;
        if (isLeapYear(year)) {
            monthDayCounts[1] = 29;
        } else {
            monthDayCounts[1] = 28;
        }
        monthDayCounts[2] = 31;
        monthDayCounts[3] = 30;
        monthDayCounts[4] = 31;
        monthDayCounts[5] = 30;
        monthDayCounts[6] = 31;
        monthDayCounts[7] = 31;
        monthDayCounts[8] = 30;
        monthDayCounts[9] = 31;
        monthDayCounts[10] = 30;
        monthDayCounts[11] = 31;

        for (i = 0; i < month - 1; i++) {
            timeStamp += DAY_IN_SECOND * monthDayCounts[i];
        }
    }

    function toDateTime(uint64 timeStamp)
        internal
        pure
        returns (DateTime memory dateTime)
    {
        dateTime.year = getYear(timeStamp);
        uint256 totalLeapYears = getTotalLeapYearBefore(dateTime.year) -
            getTotalLeapYearBefore(START_YEAR);
        uint256 totalSeconds = YEAR_IN_SECOND *
            (dateTime.year - START_YEAR - totalLeapYears) +
            LEAP_YEAR_IN_SECOND *
            totalLeapYears;

        uint256 totalSecondsInMonth;
        uint8 daysInMonth;
        uint8 i;
        for (i = 1; i <= 12; i++) {
            daysInMonth = getDaysInMonth(i, dateTime.year);
            totalSecondsInMonth = DAY_IN_SECOND * daysInMonth;
            if (totalSecondsInMonth + totalSeconds > timeStamp) {
                dateTime.month = i;
                break;
            }
            totalSeconds += totalSecondsInMonth;
        }

        for (i = 1; i <= daysInMonth; i++) {
            if (DAY_IN_SECOND + totalSeconds > timeStamp) {
                dateTime.day = i;
                break;
            }
            totalSeconds += DAY_IN_SECOND;
        }

        dateTime.hour = getHour(timeStamp);
        dateTime.minute = getMinute(timeStamp);
        dateTime.second = getSecond(timeStamp);
    }
}
