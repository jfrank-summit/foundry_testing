pragma solidity ^0.5.0;

import "../PrizeLinkedAccountVault.sol";

contract SandboxPrizeLinkedAccountVault is PrizeLinkedAccountVault {
    function makeDrawV1_Dummy(uint256 drawTimeStamp, uint256 seed)
        external
        onlyOperator
        returns (uint256)
    {
        _drawWinner[drawTimeStamp] = seed;
        emit DrawResult(drawTimeStamp, seed, seed, seed);
        return seed;
    }

    function makeDrawV1_NoValidation(uint256 drawTimeStamp, uint256 seed)
        external
        onlyOperator
        returns (uint256)
    {
        (uint256 min, uint256 max) = findMinMaxForDraw(drawTimeStamp);
        bytes memory temp = new bytes(32);
        address sender = address(this);
        assembly {
            mstore(add(temp, 32), xor(seed, sender))
        }
        uint256 drawWinner = _findDrawWinner(drawTimeStamp, min, max, temp);
        emit DrawResult(drawTimeStamp, drawWinner, min, max);
        return drawWinner;
    }

    function createPrizedLinkAccount(
        address owner,
        uint256 amount,
        uint256 dateTime,
        bytes calldata securityHash
    ) external onlyOperator returns (bool) {
        (, bytes32 depositHash) = _createSavingAccount(
            owner,
            amount,
            dateTime,
            securityHash
        );
        bool isSuccess = _createPrizedLinkTickets(depositHash);
        require(
            _token.transferFrom(owner, address(this), amount),
            "GluwaPrizeLinkedAccount: Unable to send amount to deposit to a Saving Account"
        );
        return isSuccess;
    }

    function getBalanceEachDraw(uint256 drawTimeStamp)
        external
        view
        returns (uint256)
    {
        return _balanceEachDraw[drawTimeStamp];
    }

    function setBalanceEachDraw(uint256 drawTimeStamp, uint256 amount)
        external
    {
        _balanceEachDraw[drawTimeStamp] = amount;
    }

    function createPrizedLinkAccountDummy(
        address owner,
        uint256 amount,
        bytes calldata securityHash
    ) external onlyOperator returns (bool) {
        (, bytes32 depositHash) = _createSavingAccount(
            owner,
            amount,
            now,
            securityHash
        );
        bool isSuccess = _createPrizedLinkTickets(depositHash);
        require(
            _token.transferFrom(owner, address(this), amount),
            "GluwaPrizeLinkedAccount: Unable to send amount to deposit to a Saving Account"
        );
        return isSuccess;
    }

    function depositPrizedLinkAccount(
        address owner,
        uint256 amount,
        uint256 dateTime
    ) external onlyOperator returns (bool) {
        bool isSuccess = _depositPrizedLinkAccount(
            owner,
            amount,
            dateTime,
            false
        );
        require(
            _token.transferFrom(owner, address(this), amount),
            "GluwaPrizeLinkedAccount: Unable to send amount to deposit to a Saving Account"
        );
        return isSuccess;
    }
}
