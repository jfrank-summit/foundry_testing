pragma solidity ^0.5.0;

import {DateTimeModel} from "../libs/DateTimeModel.sol";

contract Helpers {

    function getDrawTimestamp(uint64 txnTimestamp, uint8 cutoffHour, uint8 cutoffMinute) public pure returns (uint) {
        DateTimeModel.DateTime memory drawDateTime = DateTimeModel.toDateTime(
            txnTimestamp
        );
        uint8 nextDrawDay = 2;
        if (
            drawDateTime.hour < cutoffHour ||
            (drawDateTime.hour == cutoffHour &&
                drawDateTime.minute <= cutoffMinute)
        ) {
            nextDrawDay = 1;
        }
        uint8 daysInMonth = DateTimeModel.getDaysInMonth(
            drawDateTime.month,
            drawDateTime.year
        );
        if (nextDrawDay + drawDateTime.day > daysInMonth) {
            if (drawDateTime.month != 12) {
                drawDateTime.month += 1;
            } else {
                drawDateTime.year += 1;
                drawDateTime.month = 1;
            }
            drawDateTime.day = nextDrawDay + drawDateTime.day - daysInMonth;
        } else {
            drawDateTime.day = nextDrawDay + drawDateTime.day;
        }
        if (cutoffMinute == 59) {
            drawDateTime.hour = cutoffHour + 1;
            drawDateTime.minute = 0;
        } else {
            drawDateTime.hour = cutoffHour;
            drawDateTime.minute = cutoffMinute + 1;
        }

        drawDateTime.second = 0;
        uint256 drawTimeStamp = DateTimeModel.toTimeStamp(
            drawDateTime.year,
            drawDateTime.month,
            drawDateTime.day,
            drawDateTime.hour,
            drawDateTime.minute,
            drawDateTime.second
        );

        return drawTimeStamp;
    }
}