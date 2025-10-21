// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

contract KipuBank_V3 is AccessControl {
    using SafeERC20 for IERC20;

    /////////////////
    // Constants
    /////////////////
    uint8 internal constant internalDecimals = 6; // Base interna tipo USDC
    uint256 public immutable i_bankCapUSD;       // BankCap en USD internos
    uint256 public immutable i_maxWithdrawInternal; // Máximo retiro en internal decimals

    AggregatorV3Interface public immutable i_priceFeedETHUSD;

    /////////////////
    // Mappings
    /////////////////
    mapping(address => mapping(address => uint256)) public s_balances;          // token => user => balance real
    mapping(address => mapping(address => uint256)) public s_balancesInternal; // token => user => balance internal aplicado para contabilizar los valores de las tokens
    mapping(address => mapping(address => uint256)) public s_depositsCount;     // token => user => #depósitos
    mapping(address => mapping(address => uint256)) public s_withdrawalsCount;  // token => user => #retiros
    mapping(address => uint8) public s_tokenDecimals; // token => decimales reales

    /////////////////
    // Events
    /////////////////
    event DepositSuccessful(address user, address token, uint256 amount);
    event WithdrawSuccessful(address user, address token, uint256 amount);

    /////////////////
    // Errors
    /////////////////
    error KipuBank_FailedETHTransfer(bytes error);
    error KipuBank_ExceededMaxWithdraw(uint256 amount);
    error KipuBank_InsufficientBalance(uint256 balance);
    error KipuBank_ExceededBankCap();

    /////////////////
    // Constructor
    /////////////////
    constructor(
        uint256 bankCapUSD,
        uint256 maxWithdrawInternal,
        address priceFeedETHUSD
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        i_bankCapUSD = bankCapUSD;
        i_maxWithdrawInternal = maxWithdrawInternal;
        i_priceFeedETHUSD = AggregatorV3Interface(priceFeedETHUSD);
    }

    /////////////////
    // Admin functions
    /////////////////
    /// @notice Define decimales de un token
    function setTokenDecimals(address token, uint8 decimals_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        s_tokenDecimals[token] = decimals_;
    }

    /// @notice Obtiene balance de cualquier usuario
    function getUserBalance(address token, address user) external view onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        return s_balances[token][user];
    }

    /////////////////
    // Internal conversion
    /////////////////
    function toInternalDecimals(address token, uint256 amount) internal view returns (uint256) {
        uint8 tokenDecimals = s_tokenDecimals[token];
        if(tokenDecimals >= internalDecimals) {
            return amount / (10 ** (tokenDecimals - internalDecimals));
        } else {
            return amount * (10 ** (internalDecimals - tokenDecimals));
        }
    }

    function convertETHtoUSDInternal(uint256 ethAmount) public view returns (uint256) {
        (,int256 price,,,) = i_priceFeedETHUSD.latestRoundData();
        uint8 feedDecimals = i_priceFeedETHUSD.decimals();
        return (uint256(price) * ethAmount) / (10 ** feedDecimals); // en 6 decimales internos
    }

    /////////////////
    // Internal ETH deposit
    /////////////////
    function _depositETH() private {
        uint256 amount = msg.value;
        uint256 amountInternalUSD = convertETHtoUSDInternal(amount);

        if(amountInternalUSD + totalBankUSD() > i_bankCapUSD) revert KipuBank_ExceededBankCap();

        s_balances[address(0)][msg.sender] += amount;
        s_balancesInternal[address(0)][msg.sender] += amountInternalUSD;
        s_depositsCount[address(0)][msg.sender]++;

        emit DepositSuccessful(msg.sender, address(0), amount);
    }

    /////////////////
    // Deposit
    /////////////////
    /// @notice Deposita ETH o ERC-20
    function depositToken(address token, uint256 amount) external payable {
        if(token == address(0)) {
            require(msg.value > 0, "Amount must be > 0");
            _depositETH();
        } else {
            require(amount > 0, "Amount must be > 0");

            uint256 prevBalance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            uint256 received = IERC20(token).balanceOf(address(this)) - prevBalance;

            uint256 amountInternal = toInternalDecimals(token, received);

            // Effects
            s_balances[token][msg.sender] += received;
            s_balancesInternal[token][msg.sender] += amountInternal;
            s_depositsCount[token][msg.sender]++;

            emit DepositSuccessful(msg.sender, token, received);
        }
    }

    /////////////////
    // Withdraw
    /////////////////
    /// @notice Retira ETH o ERC-20
    function withdrawToken(address token, uint256 amount) external {
        uint256 balance = s_balances[token][msg.sender];
        if(balance < amount) revert KipuBank_InsufficientBalance(balance);

        uint256 amountInternal = toInternalDecimals(token, amount);
        if(amountInternal > i_maxWithdrawInternal) revert KipuBank_ExceededMaxWithdraw(amountInternal);

        // Effects
        s_balances[token][msg.sender] -= amount;
        s_balancesInternal[token][msg.sender] -= amountInternal;
        s_withdrawalsCount[token][msg.sender]++;

        // Interactions
        if(token == address(0)) {
            (bool success, bytes memory err) = msg.sender.call{value: amount}("");
            if(!success) revert KipuBank_FailedETHTransfer(err);
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit WithdrawSuccessful(msg.sender, token, amount);
    }

    /////////////////
    // View helpers
    /////////////////
    /// @notice Total ETH en USD internos
    function totalBankUSD() public view returns (uint256) {
        return convertETHtoUSDInternal(address(this).balance);
    }

    /////////////////
    // Receive & fallback
    /////////////////
    receive() external payable {
        _depositETH();
    }

    fallback() external payable {
        if(msg.value > 0) _depositETH();
    }
}
