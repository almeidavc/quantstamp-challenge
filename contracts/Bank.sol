//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";
import "./libraries/Math.sol";

contract Bank is IBank {
    using Math.sol for uint256
    
    bool internal locked;
    mapping(address => Account) public userAccount;

    address private priceOracle;
    address private HAKaddress;
    address constant private ETHaddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    modifier ETHorHAK(address token) {
      require(token == HAKaddress || token == ETHaddress, "token not supported");
      _;
    }
    
    modifier sufficientFunds(uint256 amount) {
      require(msg.value >= amount);
      _;
    }

    constructor(address _priceOracle, address _HAKaddress) {
        priceOracle = _priceOracle;
        HAKaddress = _HAKaddress;
        //HAK: 0xbefeed4cb8c6dd190793b1c97b72b60272f3ea6c
    }
    
    function updateInterest() {
        userAccounts[msg.sender].interest = block.number
            .sub(userAccounts[msg.sender].lastInterestBlock)
            .mul(0.0003)
            .mul(userAccounts[msg.sender].deposit)
            .add(userAccounts[msg.sender].interest);
        
        userAccounts[msg.sender].lastInterestBlock = block.number;
    }
     
    function deposit(address token, uint256 amount) payable external override ETHorHAK(token) returns (bool) {
        if(msg.value != amount) {
            revert("invalid deposit value");
        }
        // still have to do the conversions between eth and hak
        emit Deposit(msg.sender, token, amount);
        //computeInterest();
        uint256 res = DSMath.add(userAccount[msg.sender].deposit, amount);
        userAccount[msg.sender].deposit = res;
        return true;
    }

    function withdraw(address token, uint256 amount) external override returns (uint256) {
        updateInterest();
        
        if (token != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
        && token != 0xbefeed4cb8c6dd190793b1c97b72b60272f3ea6c
        && userAccounts[msg.sender].deposit + userAccounts[msg.sender].interest >= amount) {
            revert();
        }
        
        if (amount == 0) {
            uint256 tmp = userAccounts[msg.sender].deposit + userAccounts[msg.sender].interest;
            userAccounts[msg.sender].deposit = 0;
            userAccounts[msg.sender].interest = 0;
            msg.sender.transfer(tmp);
        }

        if (userAccounts[msg.sender].interest < amount) {
            userAccounts[msg.sender].interest = 0;
            userAccounts[msg.sender].deposit -= amount - userAccounts[msg.sender].interest;
        } else {
            userAccounts[msg.sender].interest -= amount;
        }
        
        msg.sender.transfer(amount);
        emit Withdraw(msg.sender, token, amount);
        return amount;
    }
   
    function borrow(address token, uint256 amount) external override returns (uint256) {
        // TODO
    }
     
    function repay(address token, uint256 amount) payable external override returns (uint256) {
        // TODO
    }
     
    function liquidate(address token, address account) payable external override returns (bool) {
        // TODO
    }
    
    function getCollateralRatio(address token, address account) view external override returns (uint256) {
        if (debts[account] == 0) {
            return type(uint256).max;
        }
        
        return userAccounts[account].deposit
            .wdiv(debts[account])
            .mul(10000);
    }
    
    function getBalance(address token) view external override ETHorHAK(token) returns (uint256) {
        Account memory account = userAccount[msg.sender];
        uint256 balance = account.deposit;

        // If a user withdraws their deposit earlier or later than 100 blocks, they will receive a proportional interest amount.
        // uint256 blockCount = block.number - account.lastInterestBlock;
        // if (token == HAKaddress) {
        //     deposit = convertToHAK(deposit);
        // }
        //uint256 interestRate = 0.03;
        // account.interest = depositM * (blockCount % 100) * 3 / 100;
        // depositM += account.interest;

        return balance;
    }
}
