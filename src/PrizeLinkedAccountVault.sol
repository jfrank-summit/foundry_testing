pragma solidity ^0.5.0;

import "./abstracts/VaultControl.sol";
import "./abstracts/GluwacoinSavingAccount.sol";
import "./abstracts/GluwaPrizeDraw.sol";
import "./libs/DateTimeModel.sol";

contract PrizeLinkedAccountVault is
    VaultControl,
    GluwacoinSavingAccount,
    GluwaPrizeDraw
{
    event WinnerSelected(address winner, uint256 reward);
    event Invested(address indexed recipient, uint256 amount);
    event DrawResult(uint256 indexed drawTimeStamp, uint256 winningTicket, uint256 min, uint256 max);
    event TopUpBalance(address indexed recipient, uint256 amount);
    event WithdrawBalance(address indexed recipient, uint256 amount);
    event AccountSavinSettingsUpdated(
        address opperator,
        uint32 standardInterestRate,
        uint32 standardInterestRatePercentageBase,
        uint256 budget,
        uint256 minimumDeposit,
        uint64 ticketPerToken
    );
    event GluwaPrizeDrawSettingsUpdated(
        address opperator,
        uint8 cutOffHour,
        uint8 cutOffMinute,
        uint16 processingCap,
        uint16 winningChanceFactor,
        uint128 ticketRangeFactor,
        uint8 lowerLimitPercentage
    );

    using DateTimeModel for DateTimeModel;

    uint16 private _processingCap;
    uint256 private _boostingFund;
    uint8 internal _lowerLimitPercentage;

    function initialize(
        address admin,
        address tokenAddress,
        uint32 standardInterestRate,
        uint32 standardInterestRatePercentageBase,
        uint256 budget,
        uint64 ticketPerToken,
        uint8 cutOffHour,
        uint8 cutOffMinute,
        uint16 processingCap,
        uint16 winningChanceFactor,
        uint8 lowerLimitPercentage
    ) external initializer {
        __VaultControl_Init(admin);
        __GluwacoinSavingAccount_init_unchained(
            tokenAddress,
            standardInterestRate,
            standardInterestRatePercentageBase,
            budget
        );
        __GluwaPrizeDraw_init_unchained(
            cutOffHour,
            cutOffMinute,
            _token.decimals(),
            winningChanceFactor,
            ticketPerToken
        );
        _processingCap = processingCap;
        _lowerLimitPercentage = lowerLimitPercentage;
    }

    function getVersion() external pure returns (string memory) {
        return "1.2";
    }

    function awardWinnerV1(uint256 drawTimeStamp)
        external
        onlyOperator
        returns (bool)
    {
        require(
            !_prizePayingStatus[drawTimeStamp],
            "GluwaPrizeLinkedAccount: Prize has been paid out"
        );
        address winner = getDrawWinner(drawTimeStamp);
        uint256 prize = (
            _totalPrizeBroughForward.add(_boostingFund).add(
                _balanceEachDraw[drawTimeStamp]
            )
        ).mul(_standardInterestRate).div(_standardInterestRatePercentageBase);
        _prizePayingStatus[drawTimeStamp] = true;
        if (winner != address(0)) {
            _totalPrizeBroughForward = 0;
            _depositPrizedLinkAccount(winner, prize, uint64(now), true);
        } else {
            _totalPrizeBroughForward = _totalPrizeBroughForward.add(prize);
        }
        emit WinnerSelected(winner, prize);
        return true;
    }

    function makeDrawV1(uint256 drawTimeStamp, uint256 seed)
        external
        onlyOperator
        returns (uint256)
    {
        (uint256 min, uint256 max) = findMinMaxForDraw(drawTimeStamp);
        return _makeDraw(drawTimeStamp, min, max, seed);
    }

    /// @dev when the number of participants are very high findMinMaxForDraw must be call separatedly to be provided to function
    function makeDrawV2(
        uint256 drawTimeStamp,
        uint256 min,
        uint256 max,
        uint256 seed
    ) external onlyOperator returns (uint256) {
        return _makeDraw(drawTimeStamp, min, max, seed);
    }

    function _makeDraw(
        uint256 drawTimeStamp,
        uint256 min,
        uint256 max,
        uint256 seed
    ) private returns (uint256) {
        require(
            drawTimeStamp <= now,
            "GluwaPrizeLinkedAccount: The draw can only be made on or after the draw date time"
        );
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
        bytes calldata securityHash
    ) external onlyOperator returns (bool) {
        (, bytes32 depositHash) = _createSavingAccount(
            owner,
            amount,
            uint64(now),
            securityHash
        );
        bool isSuccess = _createPrizedLinkTickets(depositHash);
        require(
            _token.transferFrom(owner, address(this), amount),
            "GluwaPrizeLinkedAccount: Unable to send amount to deposit to a Saving Account"
        );
        return isSuccess;
    }

    function depositPrizedLinkAccount(address owner, uint256 amount)
        external
        onlyOperator
        returns (bool)
    {
        bool isSuccess = _depositPrizedLinkAccount(owner, amount, uint64(now), false);
        require(
            _token.transferFrom(owner, address(this), amount),
            "GluwaPrizeLinkedAccount: Unable to send amount to deposit to a Saving Account"
        );
        return isSuccess;
    }

    function _depositPrizedLinkAccount(
        address owner,
        uint256 amount,
        uint64 dateTime,
        bool isEarning
    ) internal returns (bool) {
        bytes32 depositHash = _deposit(owner, amount, dateTime, isEarning);
        return _createPrizedLinkTickets(depositHash);
    }

    function _createPrizedLinkTickets(bytes32 referenceHash)
        internal
        onlyOperator
        returns (bool)
    {
        GluwaAccountModel.Deposit storage deposit = _depositStorage[
            referenceHash
        ];
        require(
            deposit.creationDate > 0,
            "GluwaPrizeLinkedAccount: The deposit is not found"
        );
        uint256 next2ndDraw = _calculateDrawTime(deposit.creationDate);

        if (_drawParticipantTicket[next2ndDraw][deposit.owner].length == 0) {
            _createTicketForDeposit(
                deposit.owner,
                deposit.creationDate,
                _addressSavingAccountMapping[deposit.owner].balance,
                _convertDepositToTotalTicket(
                    _addressSavingAccountMapping[deposit.owner].balance
                )
            );
        } else {
            _createTicketForDeposit(
                deposit.owner,
                deposit.creationDate,
                deposit.amount,
                _convertDepositToTotalTicket(deposit.amount)
            );
        }
        return true;
    }

    function withdrawFor(address owner, uint256 amount)
        external
        onlyOperator
        returns (bool)
    {
        return _withdrawPrizedLinkAccount(owner, owner, amount);
    }

    function withdraw(uint256 amount) external returns (bool) {
        return _withdrawPrizedLinkAccount(_msgSender(), _msgSender(), amount);
    }

    function withdrawUnclaimedAccount(address owner, address recipient)
        external
        onlyAdmin
        returns (bool)
    {
        return
            _withdrawPrizedLinkAccount(
                owner,
                recipient,
                _addressSavingAccountMapping[owner].balance
            );
    }

    function _withdrawPrizedLinkAccount(
        address owner,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        uint256 newIssued = _convertDepositToTotalTicket(amount);
        uint256 next2ndDraw = _calculateDrawTime(uint64(now));
        uint256 nextDraw = next2ndDraw.sub(86400);
        _removeTicket(owner, next2ndDraw, amount, newIssued);
        if (
            _drawParticipantTicket[nextDraw][owner].length > 0 &&
            _drawWinner[nextDraw] == 0
        ) {
            _removeTicket(owner, nextDraw, amount, newIssued);
        }
        _withdraw(owner, recipient, amount);
        return true;
    }

    function getEligibleAddressPendingAddedToDraw(uint256 drawTimeStamp)
        external
        view
        returns (address[] memory result)
    {
        uint256 t;
        uint256 i;
        address[] storage previousDrawParticipants = _drawParticipant[
            drawTimeStamp.sub(86400)
        ];
        result = new address[](previousDrawParticipants.length);
        for (i = 0; i < previousDrawParticipants.length; i++) {
            if (
                _drawParticipantTicket[drawTimeStamp][
                    previousDrawParticipants[i]
                ].length ==
                0 &&
                _addressSavingAccountMapping[previousDrawParticipants[i]]
                    .balance >
                0 &&
                _addressSavingAccountMapping[previousDrawParticipants[i]]
                    .state ==
                GluwaAccountModel.AccountState.Active
            ) {
                result[t] = previousDrawParticipants[i];
                t++;
            }
        }
        uint256 unusedSpace = i.sub(t);
        assembly {
            mstore(result, sub(mload(result), unusedSpace))
        }
    }

    function regenerateTicketForNextDraw(uint256 drawTimeStamp)
        external
        onlyOperator
        returns (uint256)
    {
        uint32 processed;
        address[] storage previousDrawParticipants = _drawParticipant[
            drawTimeStamp.sub(86400)
        ];

        for (uint256 i = 0; i < previousDrawParticipants.length; i++) {
            if (
                _drawParticipantTicket[drawTimeStamp][
                    previousDrawParticipants[i]
                ].length ==
                0 &&
                _addressSavingAccountMapping[previousDrawParticipants[i]]
                    .balance >
                0 &&
                _addressSavingAccountMapping[previousDrawParticipants[i]]
                    .state ==
                GluwaAccountModel.AccountState.Active
            ) {
                _createTicket(
                    previousDrawParticipants[i],
                    drawTimeStamp,
                    _addressSavingAccountMapping[previousDrawParticipants[i]]
                        .balance,
                    _convertDepositToTotalTicket(
                        _addressSavingAccountMapping[
                            previousDrawParticipants[i]
                        ].balance
                    )
                );
                processed++;
                if (processed >= _processingCap) break;
            }
        }
        return processed;
    }

    function invest(address recipient, uint256 amount)
        external
        onlyOperator
        returns (bool)
    {
        require(
            recipient != address(0),
            "GluwaPrizeLinkedAccount: Recipient address for investment must be defined."
        );
        uint256 totalBalance = _token.balanceOf(address(this));
        require(
            totalBalance.sub(amount) >=
                totalBalance.mul(_lowerLimitPercentage).div(100) ||
                _totalDeposit == 0,
            "GluwaPrizeLinkedAccount: the investment amount will make the total balance lower than the bottom threshold."
        );
        emit Invested(recipient, amount);
        _token.transfer(recipient, amount);
        return true;
    }

    function addBoostingFund(address source, uint256 amount)
        external
        onlyOperator
        returns (bool)
    {
        _boostingFund = _boostingFund.add(amount);
        require(
            _token.transferFrom(source, address(this), amount),
            "GluwaPrizeLinkedAccount: Unable to get the boosting fund from source"
        );
        emit TopUpBalance(source, amount);
        return true;
    }

    function withdrawBoostingFund(address recipient, uint256 amount)
        external
        onlyOperator
        returns (bool)
    {
        _boostingFund = _boostingFund.sub(amount);
        _token.transfer(recipient, amount);
        emit WithdrawBalance(recipient, amount);
        return true;
    }

    function getBoostingFund() external view returns (uint256) {
        return _boostingFund;
    }

    function setPrizeLinkedAccountSettings(
        uint32 standardInterestRate,
        uint32 standardInterestRatePercentageBase,
        uint256 budget,
        uint256 minimumDeposit,
        uint64 ticketPerToken,
        uint8 cutOffHour,
        uint8 cutOffMinute,
        uint16 processingCap,
        uint16 winningChanceFactor,
        uint128 ticketRangeFactor,
        uint8 lowerLimitPercentage
    ) external onlyOperator {
        _ticketPerToken = ticketPerToken;
        _processingCap = processingCap;
        _lowerLimitPercentage = lowerLimitPercentage;
        _setAccountSavingSettings(
            standardInterestRate,
            standardInterestRatePercentageBase,
            budget,
            minimumDeposit
        );
        _setGluwaPrizeDrawSettings(
            cutOffHour,
            cutOffMinute,
            winningChanceFactor,
            ticketRangeFactor
        );
        emit AccountSavinSettingsUpdated(
            msg.sender,
            standardInterestRate,
            standardInterestRatePercentageBase,
            budget,
            minimumDeposit,
            ticketPerToken
        );
        emit GluwaPrizeDrawSettingsUpdated(
            msg.sender,
            cutOffHour,
            cutOffMinute,
            processingCap,
            winningChanceFactor,
            ticketRangeFactor,
            lowerLimitPercentage
        );
    }

    function getPrizeLinkedAccountSettings()
        external
        view
        returns (
            uint64 ticketPerToken,
            uint16 processingCap,
            uint8 lowerLimitPercentage
        )
    {
        ticketPerToken = _ticketPerToken;
        processingCap = _processingCap;
        lowerLimitPercentage = _lowerLimitPercentage;
    }

    function getSavingAcountFor(address owner)
        external
        view
        onlyOperator
        returns (
            uint256,
            bytes32,
            address,
            uint256,
            uint256,
            uint256,
            GluwaAccountModel.AccountState,
            bytes memory
        )
    {
        return _getSavingAccountFor(owner);
    }

    function getTicketRangeById(uint256 idx)
        external
        view
        returns (
            uint96,
            address,
            uint256,
            uint256
        )
    {
        return _getTicket(idx);
    }

    function getTickerIdsByOwnerAndDraw(uint256 drawTimeStamp)
        external
        view
        returns (uint96[] memory)
    {
        return _getTickerIdsByOwnerAndDraw(drawTimeStamp, _msgSender());
    }

    function getTickerIdsByOwnerAndDrawFor(uint256 drawTimeStamp, address owner)
        external
        view
        onlyOperator
        returns (uint96[] memory)
    {
        return _getTickerIdsByOwnerAndDraw(drawTimeStamp, owner);
    }

    uint256[50] private __gap;
}
