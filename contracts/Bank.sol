//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";
import "./libraries/Math.sol";

import "./test/HAKToken.sol";

contract Bank is IBank {
    using DSMath for uint256;
    
    mapping(address => Account) public accountETH;
    mapping(address => Account) public accountHAK;
    mapping(address => Account) public accountDebt;

    IPriceOracle po;
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
    
    HAKTest private _HAK;
    constructor(address _priceOracle, address _HAKaddress) {
        po = IPriceOracle(_priceOracle);
        HAKaddress = _HAKaddress;
        _HAK = HAKTest(_HAKaddress);
    }

    // constructor() {
    //     HAKaddress = 0xBefeeD4CB8c6DD190793b1c97B72B60272f3EA6C;
    //     priceOracle = 0xc3F639B8a6831ff50aD8113B438E2Ef873845552;
    // }

    function getInterest(Account memory acc) internal view returns (uint256) {
        return block.number
            .sub(acc.lastInterestBlock)
            .mul(3)
            .wdiv(10000)
            .mul(acc.deposit) / 10 ** 18;
    }

    function updateInterest() internal {
        address account = msg.sender;
        uint256 res = getInterest(accountHAK[account]);
        accountHAK[account].interest = accountHAK[account].interest.add(res);
        accountHAK[account].lastInterestBlock = block.number;

        res = getInterest(accountETH[account]);
        accountETH[account].interest = accountHAK[account].interest.add(res);
        accountETH[account].lastInterestBlock = block.number;

        res = getInterest(accountDebt[account]);
        accountDebt[account].interest = accountDebt[account].interest.add(res);
        accountETH[account].lastInterestBlock = block.number;
    }
    
    /*
    function convertHAKToETH(uint256 amount) public returns (uint256) {
        return po.getVirtualPrice(HAKaddress);
    }
    
    function convertETHToHAK(uint256 amount) public returns (uint256) {
        return amount / po.getVirtualPrice(HAKaddress);
    }
    */
    
    function value() payable public returns (uint256) {
        return msg.value;
    }
    
    function deposit(address token, uint256 amount) payable external override ETHorHAK(token) returns (bool) {
        updateInterest();

        if (token == ETHaddress) {
            if(msg.value < amount) {
                revert("msg.value less than amount");
            }
            msg.sender.transfer(msg.value - amount);
            uint256 res = DSMath.add(accountETH[msg.sender].deposit, amount);
            accountETH[msg.sender].deposit = res;
        } 

        if (token == HAKaddress) {
            require(_HAK.allowance(msg.sender, address(this)) >= amount);
            _HAK.transferFrom(msg.sender, address(this), amount);
            uint256 res = DSMath.add(accountHAK[msg.sender].deposit, amount);
            accountHAK[msg.sender].deposit = res;
        }

        emit Deposit(msg.sender, token, amount);
        return true;
    }

    function withdraw(address token, uint256 amount) external override ETHorHAK(token) returns (uint256) {
        updateInterest();
        
        if (_getBalance(token) == 0) {
            revert("without balance");
        }

        if (_getBalance(token) < amount) {
            revert("balance too low");
        }

        // if (token == ETHaddress
        // && accountETH[msg.sender].deposit + accountETH[msg.sender].interest < amount
        // || token == HAKaddress
        // && accountHAK[msg.sender].deposit + accountHAK[msg.sender].interest < amount) {
        //     revert("no balance");
        // }
        
        if (token == ETHaddress) {
            if (amount == 0) {
                uint256 tmp = accountETH[msg.sender].deposit + accountETH[msg.sender].interest;
                accountETH[msg.sender].deposit = 0;
                accountETH[msg.sender].interest = 0;
                msg.sender.transfer(tmp);
            } else {
                if (accountETH[msg.sender].interest < amount) {
                    accountETH[msg.sender].interest = 0;
                    accountETH[msg.sender].deposit -= amount - accountETH[msg.sender].interest;
                } else {
                    accountETH[msg.sender].interest -= amount;
                }
            }
        }
        
        if (token == HAKaddress) {
            if (amount == 0) {
                uint256 tmp = accountHAK[msg.sender].deposit + accountHAK[msg.sender].interest;
                accountHAK[msg.sender].deposit = 0;
                accountHAK[msg.sender].interest = 0;
                msg.sender.transfer(tmp);
            } else {
                if (accountHAK[msg.sender].interest < amount) {
                    accountHAK[msg.sender].interest = 0;
                    accountHAK[msg.sender].deposit -= amount - accountHAK[msg.sender].interest;
                } else {
                    accountHAK[msg.sender].interest -= amount;
                }
            }
        }
        
        msg.sender.transfer(amount);
        emit Withdraw(msg.sender, token, amount);
        return amount;
    }
   
    function borrow(address token, uint256 amount) external override returns (uint256) {
        /*
        if(token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE && 
        !((accountETH[msg.sender].deposit.add(accountHAK[msg.sender].deposit.add(amount).convertHAKToETH)/debts[msg.sender] <= 1.5))) {
            revert();
        }
 
        accountDebt[msg.sender].deposit = Math.add(accountDebt[msg.sender], amount);
        msg.sender.transfer(amount);
        emit Borrow(msg, token, amount, getCollateralRatio());
        return getCollateralRatio();
        */
    }
     
    function repay(address token, uint256 amount) payable external override returns (uint256) {
        if(token != ETHaddress) {
            revert("token not supported");
        }

        if(msg.value != amount) {
            revert("invalid amount");
        }

        if (accountDebt[msg.sender].deposit + accountDebt[msg.sender].interest == 0) {
            revert("nothing to repay");
        }

        updateInterest();
        uint256 toReduce = amount;
        if (toReduce>accountDebt[msg.sender].interest) {
            accountDebt[msg.sender].interest = 0;
            toReduce = toReduce - accountDebt[msg.sender].interest;
        } 
        else{
            accountDebt[msg.sender].interest = accountDebt[msg.sender].interest - toReduce;
            emit Repay(msg.sender, token, accountDebt[msg.sender].deposit);
            return accountDebt[msg.sender].deposit;
        }
        accountDebt[msg.sender].deposit = accountDebt[msg.sender].deposit - toReduce;
        emit Repay(msg.sender, token, accountDebt[msg.sender].deposit);
        return accountDebt[msg.sender].deposit;
    }
    
     
    function liquidate(address token, address account) payable external override returns (bool) {
        // Only support HAK as collateral token
        require(token == HAKaddress, "token not supported");
        // Prevent a user from liquidating own account
        require(account != msg.sender, "cannot liquidate own position");
        // Collateral ratio must be lower than 150%
        require((_getCollateralRatio(token, account) < 15000 && _getCollateralRatio(token, account) > 0), "healty position");
        // Liquidator must have sufficient ETH
        require(msg.value >= accountDebt[account].deposit, "insufficient ETH sent by liquidator");


        // if everything is fine
        uint256 sendBackAmount = 0;
        if (msg.value > accountDebt[account].deposit) {
             sendBackAmount = DSMath.sub(msg.value, accountDebt[account].deposit);
        } 
        uint256 collateralAmount = accountHAK[account].deposit;
        msg.sender.transfer(collateralAmount);
        accountDebt[account].deposit = 0;
        accountHAK[account].deposit = 0;
        emit Liquidate(msg.sender, account, token, collateralAmount, sendBackAmount);
        return true;
        
    }

    function _getCollateralRatio(address token, address account) view internal returns (uint256) {
        /*8
        if (debts[account] == 0) {
            return type(uint256).max;
        }
        
        return userAccounts[account].deposit
            .wdiv(debts[account])
            .mul(10000);
        */
    }
    
    function getCollateralRatio(address token, address account) view external override returns (uint256) {
        return _getCollateralRatio(token, account);
    }
    
    function _getBalance(address token) view internal ETHorHAK(token) returns (uint256) {
        uint256 balance;
        if (token == ETHaddress) {
            balance = accountETH[msg.sender].deposit.add(getInterest(accountETH[msg.sender]));
        }
        if (token == HAKaddress) {
            balance = accountHAK[msg.sender].deposit.add(getInterest(accountHAK[msg.sender]));
        }
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


    function getBalance(address token) view external override ETHorHAK(token) returns (uint256) {
        return _getBalance(token);
    }
}
