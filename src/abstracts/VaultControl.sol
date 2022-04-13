pragma solidity ^0.5.0;

import "@openzeppelin/contracts/GSN/Context.sol";
import "../Initializable.sol";
import "../libs/AccessControl.sol";

contract VaultControl is Initializable, Context, AccessControlUpgradeSafe {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR");

    function __VaultControl_Init(address account) internal initializer {
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, account);
        _setupRole(OPERATOR_ROLE, account);
    }

    /// @dev Restricted to members of the admin role.
    modifier onlyAdmin() {
        require(isAdmin(_msgSender()), "Restricted to Admins.");
        _;
    }

    /// @dev Restricted to members of the Operator role.
    modifier onlyOperator() {
        require(isOperator(_msgSender()), "Restricted to Operators.");
        _;
    }

    /// @dev Return `true` if the account belongs to the admin role.
    function isAdmin(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// @dev Add an account to the admin role. Restricted to admins.
    function addAdmin(address account) external onlyAdmin {
        grantRole(OPERATOR_ROLE, account);
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /// @dev Return `true` if the account belongs to the operator role.
    function isOperator(address account) public view returns (bool) {
        return hasRole(OPERATOR_ROLE, account);
    }

    /// @dev Add an account to the operator role. Restricted to admins.
    function addOperator(address account) external onlyAdmin {
        grantRole(OPERATOR_ROLE, account);
    }

    /// @dev Remove an account from the Operator role. Restricted to admins.
    function removeOperator(address account) external onlyAdmin {
        revokeRole(OPERATOR_ROLE, account);
    }

    /// @dev Remove oneself from the Admin role thus all other roles.
    function renounceAdmin() external {
        address sender = _msgSender();
        renounceRole(DEFAULT_ADMIN_ROLE, sender);
        renounceRole(OPERATOR_ROLE, sender);
    }

    /// @dev Remove oneself from the Operator role.
    function renounceOperator() external {
        renounceRole(OPERATOR_ROLE, _msgSender());
    }

    uint256[50] private __gap;
}
