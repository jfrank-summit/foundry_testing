pragma solidity 0.5.0;

import "ds-test/test.sol";
import "../PrizeLinkedAccountVault.sol";
import {CheatCodes} from "./utils/cheatcodes.sol";
import {SandboxGluwacoin} from  "../mocks/SandboxGluwacoin.sol";
import "forge-std/console.sol";
import "../libs/GluwaAccountModel.sol";

contract PrizedLinkTesting is DSTest {
    using console for console;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    PrizeLinkedAccountVault prizeLinkedAccount;
    SandboxGluwacoin gluwacoin;

    address owner;
    address user1 = address(1);
    address user2 = address(2);
    
    uint256 constant DECIMALS_VAL = 10**18;
    uint256 constant BUDGET = 20_000_000_000*DECIMALS_VAL;
    uint256 constant DEPOSIT_AMOUNT = 2_000_000*DECIMALS_VAL;
    uint256 constant MINT_AMOUNT = DEPOSIT_AMOUNT*2;

    function mintAndApprove(address _to, uint256 _amount) public {
        gluwacoin.mint(_to, _amount);
        
        cheats.prank(_to);
        gluwacoin.approve(address(prizeLinkedAccount), _amount);
    }
    function setUp() public {
        cheats.warp(1);
        owner = address(this);
        gluwacoin = new SandboxGluwacoin("Gluwacoin", "Gluwacoin", 18);
        
        prizeLinkedAccount = new PrizeLinkedAccountVault();

        prizeLinkedAccount.initialize(owner, address(gluwacoin), 15, 100, BUDGET, 1, 16, 59, 110, 3, 30);
        
        mintAndApprove(owner, MINT_AMOUNT);
        mintAndApprove(user1, MINT_AMOUNT);
        mintAndApprove(user2, MINT_AMOUNT);
    }

    function testTokenBalances() public {
        assertTrue(gluwacoin.balanceOf(owner) == MINT_AMOUNT);
        assertTrue(gluwacoin.balanceOf(user1) == MINT_AMOUNT);
        assertTrue(gluwacoin.balanceOf(user1) == MINT_AMOUNT);
    }
    
    function testTokenAllowance() public {
        assertTrue(gluwacoin.allowance(owner, address(prizeLinkedAccount)) == MINT_AMOUNT);
        assertTrue(gluwacoin.allowance(user1, address(prizeLinkedAccount)) == MINT_AMOUNT);
        assertTrue(gluwacoin.allowance(user2, address(prizeLinkedAccount)) == MINT_AMOUNT);
    }

    function testHashDifferent() public {
        bytes memory hash1 = abi.encodePacked(user1);        
        console.logBytes(hash1);
        console.logAddress(user1);
        
        prizeLinkedAccount.createPrizedLinkAccount(user1, DEPOSIT_AMOUNT, hash1);

        //GluwaAccountModel.SavingAccount memory account = prizeLinkedAccount.getAccount(user1);
        // bytes32 depositHash = GluwaAccountModel.generateHash(
        //     account.idx, now, DEPOSIT_AMOUNT, address(prizeLinkedAccount), owner);
        prizeLinkedAccount.depositPrizedLinkAccount(user1, DEPOSIT_AMOUNT);

        // cheats.expectEmit(true, true, false, false);
        // emit DepositCreated()
    }
}
