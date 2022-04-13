pragma solidity ^0.5.0;

/** @title Library functions used by contracts within this ecosystem.*/
library UintArrayUtil {
    function removeByIndex(uint256[] storage self, uint256 index) internal {
        if (index >= self.length) return;

        for (uint256 i = index; i < self.length - 1; i++) {
            self[i] = self[i + 1];
        }
        self.length--;
    }

    /// @dev the value for each item in the array must be unique
    function removeByValue(uint256[] storage self, uint256 val) internal {
        if (self.length == 0) return;
        uint256 j = 0;
        for (uint256 i = 0; i < self.length - 1; i++) {
            if (self[i] == val) {
                j = i + 1;
            }
            self[i] = self[j];
            j++;
        }
        self.length--;
    }

    /// @dev add new item into the array
    function add(uint256[] storage self, uint256 val) internal {
        self.push(val);
    }
}
