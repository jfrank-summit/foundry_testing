pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "../Initializable.sol";
import "../abstracts/IERC20.sol";
import "../libs/GluwaAccountModel.sol";
import "../libs/HashMapIndex.sol";
import "../libs/UintArrayUtil.sol";
 
contract GluwacoinSavingAccountMock is Initializable, Context {
    using HashMapIndex for HashMapIndex.HashMapping;
    using SafeMath for uint256;
    using UintArrayUtil for uint256[];

    uint256 private _budget;
    uint256 private _minimumDeposit;
    uint256 internal _totalDeposit;
    address[] internal _owners;

    HashMapIndex.HashMapping private _savingAccountIndex;
    HashMapIndex.HashMapping private _depositIndex;

    uint32 internal _standardInterestRate;
    /**
     * @dev
        if interest rate is 15%, the interestRatePercentageBase is 100 and interestRate is 15
        if interest rate is 15.5%, the interestRatePercentageBase is 1000 and interestRate is 155
     */
    uint32 internal _standardInterestRatePercentageBase;
    /// @dev The total amount users deposit to this Saving contract minus the withdrawn principal
    uint256 internal _allTimeTotalContractDeposit;

    /// @dev The supported token which can be deposited to a Saving account.
    IERC20 internal _token;
    /// @dev The total holding balance is SUM of all principal and yeild of non-matured Saving.
    mapping(address => GluwaAccountModel.SavingAccount)
        internal _addressSavingAccountMapping;
    mapping(bytes32 => GluwaAccountModel.Deposit) internal _depositStorage;
    mapping(bytes => bool) private _usedIdentityHash;
    //mapping(bytes32 => GluwaAccountModel.SavingAccount) internal _savingAccountStorage;

    event AccountCreated(bytes32 indexed accountHash, address indexed owner);

    event DepositCreated(
        bytes32 indexed depositHash,
        address indexed owner,
        uint256 deposit
    );

    event Withdrawn(
        address indexed owner,
        address indexed recipient,
        uint256 amount
    );

    function __GluwacoinSavingAccount_init_unchained(
        address tokenAddress,
        uint32 standardInterestRate,
        uint32 standardInterestRatePercentageBase,
        uint256 budget
    ) internal initializer {
        _token = IERC20(tokenAddress);
        _standardInterestRate = standardInterestRate;
        _standardInterestRatePercentageBase = standardInterestRatePercentageBase;
        _budget = budget;
        _minimumDeposit = 1;
        _savingAccountIndex = HashMapIndex.HashMapping({
            firstIdx: 1,
            nextIdx: 1,
            count: 0
        });
        _depositIndex = HashMapIndex.HashMapping({
            firstIdx: 1,
            nextIdx: 1,
            count: 0
        });
    }

    function _getSavingAccountFor(address account)
        internal
        view
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
        GluwaAccountModel.SavingAccount
            storage SavingAccount = _addressSavingAccountMapping[account];
        return (
            SavingAccount.idx,
            SavingAccount.accountHash,
            SavingAccount.owner,
            SavingAccount.creationDate,
            SavingAccount.balance,
            SavingAccount.earning,
            SavingAccount.state,
            SavingAccount.securityReferenceHash
        );
    }

    function _createSavingAccount(
        address owner_,
        uint256 initialDeposit,
        uint256 startDate,
        bytes memory identityHash
    ) internal returns (bytes32, bytes32) {
        _validateSavingBalance(initialDeposit);
        require(
            owner_ != address(0),
            "GluwaSavingAccount: Saving owner address must be defined"
        );
        require(
            _addressSavingAccountMapping[owner_].creationDate == 0,
            "GluwaSavingAccount: Each address should have only 1 Saving account only"
        );
        require(
            _usedIdentityHash[identityHash] == false,
            "GluwaSavingAccount: Identity hash is already used"
        );

        bytes32 accountHash_ = GluwaAccountModel.generateHash(
            _savingAccountIndex.nextIdx,
            startDate,
            initialDeposit,
            address(this),
            owner_
        );

        _addressSavingAccountMapping[owner_] = GluwaAccountModel.SavingAccount({
            idx: _savingAccountIndex.nextIdx,
            accountHash: accountHash_,
            owner: owner_,
            balance: 0,
            creationDate: startDate,
            earning: 0,
            state: GluwaAccountModel.AccountState.Active,
            securityReferenceHash: identityHash
        });
       
        _usedIdentityHash[identityHash] = true;
        _savingAccountIndex.add(accountHash_);
        _owners.push(owner_);

        bytes32 depositHash = _deposit(owner_, initialDeposit, startDate, false);

        emit AccountCreated(accountHash_, owner_);

        return (accountHash_, depositHash);
    }

    function _createSavingAccountDummy(
        address owner_,
        uint256 initialDeposit,
        uint256 startDate,
        bytes memory identityHash
    ) internal returns (bytes32, bytes32) {
        _validateSavingBalance(initialDeposit);
        require(
            owner_ != address(0),
            "GluwaSavingAccount: Saving owner address must be defined"
        );

        bytes32 accountHash_ = GluwaAccountModel.generateHash(
            _savingAccountIndex.nextIdx,
            startDate,
            initialDeposit,
            address(this),
            owner_
        );

        _addressSavingAccountMapping[owner_] = GluwaAccountModel.SavingAccount({
            idx: _savingAccountIndex.nextIdx,
            accountHash: accountHash_,
            owner: owner_,
            balance: 0,
            creationDate: startDate,
            earning: 0,
            state: GluwaAccountModel.AccountState.Active,
            securityReferenceHash: identityHash
        });
       
        _usedIdentityHash[identityHash] = true;
        _savingAccountIndex.add(accountHash_);
        _owners.push(owner_);

        bytes32 depositHash = _deposit(owner_, initialDeposit, startDate, false);

        emit AccountCreated(accountHash_, owner_);

        return (accountHash_, depositHash);
    }
    function _withdraw(
        address owner,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        GluwaAccountModel.SavingAccount
            storage account = _addressSavingAccountMapping[owner];
        require(
            account.balance >= amount &&
                account.state == GluwaAccountModel.AccountState.Active,
            "GluwaSavingAccount: Withdrawal amount is higher than deposit or the saving account must be active"
        );
        account.balance -= amount;
        _totalDeposit -= amount;
        _token.transfer(recipient, amount);
        emit Withdrawn(owner, recipient, amount);
        return account.balance;
    }

    function _deposit(
        address owner,
        uint256 amount,
        uint256 dateTime,
        bool isEarning
    ) internal returns (bytes32) {
        _validateSavingBalance(amount);

        GluwaAccountModel.SavingAccount
            storage account = _addressSavingAccountMapping[owner];

        require(
            account.creationDate > 0,
            "GluwaSavingAccount: Account not found"
        );

        account.balance += amount;
        if (isEarning) {
            account.earning += amount;
        } 
        bytes32 depositHash = GluwaAccountModel.generateHash(
            account.idx,
            dateTime,
            amount,
            address(this),
            owner
        );
        _depositStorage[depositHash] = GluwaAccountModel.Deposit({
            idx: _depositIndex.nextIdx,
            owner: owner,
            creationDate: dateTime,
            amount: amount,
            accountIdx: account.idx
        });
        _depositIndex.add(depositHash);
        _allTimeTotalContractDeposit += amount;
        _totalDeposit += amount;

        emit DepositCreated(depositHash, owner, amount);
        return depositHash;
    }

    function getDeposit(bytes32 depositHash)
        public
        view
        returns (
            uint256,
            uint256,
            address,
            uint256,
            uint256
        )
    {
        GluwaAccountModel.Deposit storage deposit = _depositStorage[
            depositHash
        ];
        return (
            deposit.idx,
            deposit.accountIdx,
            deposit.owner,
            deposit.creationDate,
            deposit.amount
        );
    }

    function getSavingAcount()
        external
        view
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
        return _getSavingAccountFor(_msgSender());
    }

    /**
     * @return all the Saving's settings;.
     */
    function getSavingSettings()
        public
        view
        returns (
            uint32,
            uint32,
            uint256,
            uint256,
            IERC20
        )
    {
        return (
            _standardInterestRate,
            _standardInterestRatePercentageBase,
            _budget,
            _minimumDeposit,
            _token
        );
    }

    function _setAccountSavingSettings(
        uint32 standardInterestRate,
        uint32 standardInterestRatePercentageBase,
        uint256 budget,
        uint256 minimumDeposit
    ) internal {
        _standardInterestRate = standardInterestRate;
        _standardInterestRatePercentageBase = standardInterestRatePercentageBase;
        _budget = budget;
        _minimumDeposit = minimumDeposit;
    }

    /**
     * @dev calculate earning for given amount based on term and interest rate.
            if interest rate is 15%, the interestRatePercentageBase is 100 and interestRate is 15
            if interest rate is 15.5%, the interestRatePercentageBase is 1000 and interestRate is 155
     */
    function _calculateearning(
        uint64 term,
        uint32 interestRate,
        uint32 interestRatePercentageBase,
        uint256 amount
    ) private pure returns (uint256) {
        uint256 earning = amount
            .mul(interestRate)
            .div(interestRatePercentageBase)
            .mul(term)
            .div(31536000); /// @dev 365 days in seconds
        return earning;
    }

    function _validateSavingBalance(uint256 deposit) private view {
        require(
            deposit >= _minimumDeposit &&
                deposit.add(_allTimeTotalContractDeposit) <= _budget,
            "GluwacoinSaving: the deposit must be >= min deposit & cannot make the total balance > the budget."
        );
    }

    uint256[50] private __gap;
}
