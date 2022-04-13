pragma solidity ^0.5.0;


/** @title Simple hash map index library without status to be used by contracts within this ecosystem.*/
library HashMapIndex {
    
    /**
     * @dev Efficient storage container for hashes enabling iteration
     */
    struct HashMapping {        
        mapping(uint256 => bytes32) itHashMap;
        uint256 firstIdx;
        uint256 nextIdx;
        uint256 count;
    }

    /**
     * @dev Add a new hash to the storage container if it is not yet part of it
     * @param self Struct storage container pointing to itself
     * @param _hash Hash to add to the struct
     */
    function add(HashMapping storage self, bytes32 _hash) internal {        
        self.itHashMap[self.nextIdx] = _hash;
        self.nextIdx++;
        self.count++;
    }   

    /**
     * @dev Retrieve the specified (_idx) hash from the struct
     * @param self Struct storage container pointing to itself
     * @param _idx Index of the hash to retrieve
     * @return Hash specified by the _idx value (returns 0x0 if _idx is an invalid index)
     */
    function get(HashMapping storage self, uint256 _idx)
        internal
        view
        returns (bytes32)
    {
        return self.itHashMap[_idx];
    }
}