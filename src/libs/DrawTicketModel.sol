pragma solidity ^0.5.0;

/** @title Library functions used by contracts within this ecosystem.*/
library DrawTicketModel {   

    struct DrawTicket {
        // Memory layout for ticket identifier:    
        // - 12 bytes for idx;
        // - 20 bytes for owner address;
        uint256 identifier;        
        uint256 lower;        
        uint256 upper;
    }    
}
