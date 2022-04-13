pragma solidity 0.5.0;

import "ds-test/test.sol";
import "../PrizeLinkedAccountVault.sol";
import "forge-std/console.sol";
import {CheatCodes} from "./utils/cheatcodes.sol";

import {SandboxGluwacoin} from "../mocks/SandboxGluwacoin.sol";
import "../libs/GluwaAccountModel.sol";
import "../abstracts/GluwaPrizeDraw.sol";
import "./helpers.sol";


contract PrizedLinkTesting is DSTest {
    using console for console;
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    PrizeLinkedAccountVault prizeLinkedAccount;
    SandboxGluwacoin gluwacoin;
    Helpers helpers;

    address owner;
    address user1 = address(1);
    address user2 = address(2);

    uint256 constant DECIMALS_VAL = 10**18;
    uint256 constant BUDGET = 20_000_000_000 * DECIMALS_VAL;
    uint256 constant DEPOSIT_AMOUNT = 2_000_000 * DECIMALS_VAL;
    uint256 constant MINT_AMOUNT = DEPOSIT_AMOUNT * 5;

    event TicketCreated(
        uint256 indexed drawTimeStamp,
        uint256 indexed ticketId,
        address indexed owner,
        uint256 upper,
        uint256 lower
    );

    event DepositCreated(
        bytes32 indexed depositHash,
        address indexed owner,
        uint256 deposit
    );

    function setUp() public {
        cheats.warp(1);

        owner = address(this);

        helpers = new Helpers();

        gluwacoin = new SandboxGluwacoin("Gluwacoin", "Gluwacoin", 18);
        prizeLinkedAccount = new PrizeLinkedAccountVault();
        prizeLinkedAccount.initialize(
            owner,
            address(gluwacoin),
            15,
            100,
            BUDGET,
            1,
            16,
            59,
            110,
            3,
            30
        );

        mintAndApprove(owner, MINT_AMOUNT);
        mintAndApprove(user1, MINT_AMOUNT);
        mintAndApprove(user2, MINT_AMOUNT);
    }

    function mintAndApprove(address _to, uint256 _amount) public {
        gluwacoin.mint(_to, _amount);

        cheats.prank(_to);
        gluwacoin.approve(address(prizeLinkedAccount), _amount);
    }

    function getDrawTimestamp(uint256 txnTimestamp)
        public
        view
        returns (uint256)
    {
        (uint8 cutoffHour, uint8 cutoffMinute, , ) = prizeLinkedAccount
            .getGluwaPrizeDrawSettings();
        return helpers.getDrawTimestamp(txnTimestamp, cutoffHour, cutoffMinute);
    }

    function multipleDeposits(bytes32 depositHash) public {      

        cheats.expectEmit(true, false, false, false);
        emit DepositCreated(depositHash, user1, DEPOSIT_AMOUNT);
        prizeLinkedAccount.depositPrizedLinkAccount(user1, DEPOSIT_AMOUNT);

        cheats.expectEmit(true, false, false, false);
        emit DepositCreated(depositHash, user1, DEPOSIT_AMOUNT);
        prizeLinkedAccount.depositPrizedLinkAccount(user1, DEPOSIT_AMOUNT);
    }

    function testTokenBalances() public {
        assertTrue(gluwacoin.balanceOf(owner) == MINT_AMOUNT);
        assertTrue(gluwacoin.balanceOf(user1) == MINT_AMOUNT);
        assertTrue(gluwacoin.balanceOf(user1) == MINT_AMOUNT);
    }

    function testTokenAllowance() public {
        assertTrue(
            gluwacoin.allowance(owner, address(prizeLinkedAccount)) ==
                MINT_AMOUNT
        );
        assertTrue(
            gluwacoin.allowance(user1, address(prizeLinkedAccount)) ==
                MINT_AMOUNT
        );
        assertTrue(
            gluwacoin.allowance(user2, address(prizeLinkedAccount)) ==
                MINT_AMOUNT
        );
    }

    function testCreatePrizeLinkedDrawTimestamp() public {
        uint256 drawTimestamp = getDrawTimestamp(now);

        cheats.expectEmit(true, false, false, false);
        emit TicketCreated(drawTimestamp, 0, user1, 0, 0);
        prizeLinkedAccount.createPrizedLinkAccount(
            user1,
            DEPOSIT_AMOUNT,
            abi.encodePacked(user1)
        );
    }

    function testDepositPrizeLinkedDrawTimestamp() public {
        prizeLinkedAccount.createPrizedLinkAccount(
            user1,
            DEPOSIT_AMOUNT,
            abi.encodePacked(user1)
        );

        uint256 drawTimestamp = getDrawTimestamp(now);

        cheats.expectEmit(true, false, false, false);
        emit TicketCreated(drawTimestamp, 0, user1, 0, 0);
        prizeLinkedAccount.depositPrizedLinkAccount(user1, DEPOSIT_AMOUNT);
    }

    function testDepositCreatedMatches() public {
        prizeLinkedAccount.createPrizedLinkAccount(
            user1,
            DEPOSIT_AMOUNT,
            abi.encodePacked(user1)
        );
        
        (uint256 accountIdx, , , , , , , ) = prizeLinkedAccount
            .getSavingAcountFor(user1);

        bytes32 depositHash = GluwaAccountModel.generateHash(
            accountIdx,
            now,
            DEPOSIT_AMOUNT,
            address(prizeLinkedAccount),
            user1
        );

        cheats.expectEmit(true, true, false, false);
        emit DepositCreated(depositHash, user1, DEPOSIT_AMOUNT);
        prizeLinkedAccount.depositPrizedLinkAccount(user1, DEPOSIT_AMOUNT);   
    }

    
    function testSubsequentDepositHashesDontMatch() public {
        prizeLinkedAccount.createPrizedLinkAccount(
            user1,
            DEPOSIT_AMOUNT,
            abi.encodePacked(user1)
        );
        
        (uint256 accountIdx, , , , , , , ) = prizeLinkedAccount
            .getSavingAcountFor(user1);

        bytes32 depositHash = GluwaAccountModel.generateHash(
            accountIdx,
            now,
            DEPOSIT_AMOUNT,
            address(prizeLinkedAccount),
            user1
        );

        cheats.expectRevert(bytes("test"));
        multipleDeposits(depositHash);    
    }

    function testEligbleAddressDrawsIsZero() public {
        prizeLinkedAccount.createPrizedLinkAccount(
            user1,
            DEPOSIT_AMOUNT,
            abi.encodePacked(user1)
        );
        uint256 drawTimestamp = getDrawTimestamp(now);

        assertTrue(
            prizeLinkedAccount
                .getEligibleAddressPendingAddedToDraw(drawTimestamp)
                .length == 0
        );
    }

    function testUserHasOneDraw() public {
        prizeLinkedAccount.createPrizedLinkAccount(
            user1,
            DEPOSIT_AMOUNT,
            abi.encodePacked(user1)
        );
        uint256 drawTimestamp = getDrawTimestamp(now);

        cheats.warp(drawTimestamp);
        uint96[] memory user1Draws = prizeLinkedAccount
            .getTickerIdsByOwnerAndDrawFor(drawTimestamp, user1);
        //console.logAddress(eligibleAddressesPending[0]);
        assertTrue(user1Draws.length == 1);
    }

    function testUserHasTwoDraws() public {
        prizeLinkedAccount.createPrizedLinkAccount(
            user1,
            DEPOSIT_AMOUNT / 2,
            abi.encodePacked(user1)
        );
        prizeLinkedAccount.depositPrizedLinkAccount(user1, DEPOSIT_AMOUNT / 2);
        uint256 drawTimestamp = getDrawTimestamp(now);

        cheats.warp(drawTimestamp);
        uint96[] memory user1Draws = prizeLinkedAccount
            .getTickerIdsByOwnerAndDrawFor(drawTimestamp, user1);
        assert(user1Draws.length == 2);
    }
}
