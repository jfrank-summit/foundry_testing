pragma solidity ^0.5.0;


/** @title Simple index library without status to be used by contracts within this ecosystem.*/
library SimpleIndex {

    
    /**
     * @dev Efficient storage container for hashes enabling iteration
     */
    struct Index {   
        uint56 nextIdx;
    }

    /**
     * @dev Add a index to the storage container if it is not yet part of it
     * @param self Struct storage container pointing to itself
     */
    function add(Index storage self) internal {        
        self.nextIdx++;
    }   

     /**
     * @dev Add a index to the storage container if it is not yet part of it
     * @param self Struct storage container pointing to itself
     */
    function set(Index storage self, uint56 next) internal {        
        self.nextIdx = next;
    }   
    
}