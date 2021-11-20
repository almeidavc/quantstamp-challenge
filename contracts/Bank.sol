//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";
import "./libraries/Math.sol";

contract Bank is IBank {
    using DSMath for uint256;
    
    mapping(address => Account) public accountETH;
    mapping(address => Account) public accountHAK;
    mapping(address => Account) public accountDebt;

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
    
    /* function updateInterest() internal {
        userAccounts[msg.sender].interest = block.number
            .sub(userAccounts[msg.sender].lastInterestBlock)
            .mul(0.0003)
            .mul(userAccounts[msg.sender].deposit)
            .add(userAccounts[msg.sender].interest);
        
        userAccounts[msg.sender].lastInterestBlock = block.number;
     } */
    
   
    function updateInterest(address account) internal {
        uint256 toAdd = block.number
            .sub(accountETH[msg.sender].lastInterestBlock)
            .mul(0.0003)
            .mul(accountETH[msg.sender].deposit)

        accountEth[msg.sender].interest.add(toAdd);
        accountEth[msg.sender].lastInterestBlock = block.number;

        toAdd = block.number
            .sub(accountHAK[msg.sender].lastInterestBlock)
            .mul(0.0003)
            .mul(accountHAK[msg.sender].deposit)

        accountHak[msg.sender].interest.add(toAdd);
        accountHak[msg.sender].lastInterestBlock = block.number;

        toAdd = block.number
            .sub(accountDebt[msg.sender].lastInterestBlock)
            .mul(0.0005)
            .mul(AccountDebt[msg.sender].deposit)

        AccountDebt[msg.sender].interest.add(toAdd);
        userAccounts[msg.sender].lastInterestBlock = block.number;
    }
     
    /**
     * The purpose of this function is to allow end-users to deposit a given 
     * token amount into their bank account.
     * @param token - the address of the token to deposit. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to deposit is ETH.
     * @param amount - the amount of the given token to deposit.
     * @return - true if the deposit was successful, otherwise revert.
     */
    function deposit(address token, uint256 amount) payable external override ETHorHAK(token) returns (bool) {
        if(msg.value < amount) {
            revert();
        }
        msg.sender.transfer(msg.value - amount);
        updateInterest();
        
        if (token == ETHaddress) {
            uint256 res = DSMath.add(accountETH[msg.sender].deposit, amount);
            accountETH[msg.sender].deposit = res;
        } 
        
        if (token == HAKaddress) {
            uint256 res = DSMath.add(accountHAK[msg.sender].deposit, amount);
            accountHAK[msg.sender].deposit = res;
        }

        emit Deposit(msg.sender, token, amount);
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
        if(!(token == 0xbefeed4cb8c6dd190793b1c97b72b60272f3ea6c && token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE && 
        !((userAccount[msg.sender].deposit+amount)/debts[msg.sender] <= 1.5))) {
            revert();
        }
        debts[msg.sender] = Math.add(debts[msg.sender], amount);
        msg.sender.transfer(amount);
        return getCollateralRatio();
    }
     
    function repay(address token, uint256 amount) payable external override returns (uint256) {
        // TODO
        
        //debt still has to be implemented
        
        if(!(token == 0xbefeed4cb8c6dd190793b1c97b72b60272f3ea6c && token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) && 
        !(msg.value == amount)) {
            revert();
        }
        updateInterest();
        uint256 toReduce = amount;
        if (toReduce>interestOwed[msg.sender]) {
            interestOwed[msg.sender] = 0;
            toReduce = toReduce - interestOwed[msg.sender];
        } 
        else{
            interestOwed[msg.sender] = interest[msg.sender] - toReduce;
            emit Repay(msg.sender, token, debts[msg.sender]);
            return debts[msg.sender];
        }
        debts[msg.sender] = debts[msg.sender] - toReduce;
        emit Repay(msg.sender, token, debts[msg.sender]);
        return debts[msg.sender];
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
