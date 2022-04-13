pragma solidity ^0.5.0;

/** @title Library functions used by contracts within this ecosystem.*/
library GluwaAccountModel {
    /**
     * @dev Enum of the different states a Account Account can be in.
     */
    enum AccountState {
        /*0*/
        Pending,
        /*1*/
        Active,
        /*2*/
        Defaulted,
        /*3*/
        Locked,
        /*4*/
        Closed
    }

    struct Deposit {
        // Index of this Deposit
        uint256 idx;
        uint256 accountIdx;
        // address of the Account owner
        address owner;
        uint64 creationDate;
        uint256 amount;
    }

    struct SavingAccount {
        // Index of this account
        uint256 idx;
        bytes32 accountHash;
        // address of the Account owner
        address owner;        
        uint64 creationDate;
        uint256 balance;
        uint256 earning;
        // Different states a Account can be in
        AccountState state;
        bytes securityReferenceHash;
    }

    function generateHash(
        uint256 id,
        uint256 timestamp,
        uint256 deposit,
        address contractAddress,
        address owner
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, timestamp, deposit, contractAddress, owner));
    }

    // function generateDepositHash(
    //     uint256 id,
    //     uint256 deposit,
    //     address contractAddress,
    //     uint256 creationDate,
    //     address owner
    // ) public pure returns (bytes32) {
    //     return keccak256(abi.encodePacked(id, deposit, contractAddress, creationDate, owner));
    // }

    // function generateAccountHash(
    //     uint256 startDate, 
    //     address contractAddress,
    //     address owner
    // ) public pure returns (bytes32) {
    //     return
    //         keccak256(
    //             abi.encodePacked(
    //                 startDate,
    //                 "SavingAccount",
    //                 contractAddress,
    //                 owner
    //             )
    //         );
    // }
}
