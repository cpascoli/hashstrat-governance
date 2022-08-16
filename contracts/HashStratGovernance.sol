// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IPoolV2.sol";

contract HashStratGovernance is Ownable {

    // the addresses of LP tokens of the HashStrat Pools and Indexes supported
    address[] internal poolsArray;
    mapping(address => bool) internal enabledPools;

    IERC20Metadata public feesToken;

    address[] internal poolLPTokensArray;


    uint public totalFeesCollected;
    uint public totalFeesTransferred;

    constructor(address feesTokenAddress) {
        feesToken = IERC20Metadata(feesTokenAddress);
    }



    //// Public View function ////

    function feesBalance() public view returns (uint) {
        return feesToken.balanceOf(address(this));
    }


    function collectableFees() public view returns (uint) {
        uint total = 0;
        for (uint i = 0; i < poolsArray.length; i++) {
            if (enabledPools[poolsArray[i]]) {
                IPoolV2 pool = IPoolV2(poolsArray[i]);
                total += pool.lpToken().balanceOf(address(pool));
            }
        }

        return total;
    }


    function getPools() external view returns (address[] memory) {
        return poolsArray;
    }


    function getPoolLPTokens() external view returns (address[] memory) {
        return poolLPTokensArray;
    }



    //// Governance Functionality  ////



    //// Fees Management ////
    function collectFees() external onlyOwner {

        uint feesBefore = feesBalance();

        for (uint i = 0; i < poolsArray.length; i++) {
            if (enabledPools[poolsArray[i]]) {
                IPoolV2 pool = IPoolV2(poolsArray[i]);
                pool.withdrawFees(0);
            }
        }

        uint collected = feesBalance() - feesBefore;
        totalFeesCollected += collected;
    }


    function transferFees(address to, uint amount) external onlyOwner {
        uint feesAmount = amount == 0 ? feesToken.balanceOf(address (this)) : amount;

        if (feesAmount > 0) {
            totalFeesTransferred += feesAmount;
            feesToken.transfer(to, feesAmount);
        }
    }


    function approveFeeTransfer(address spender, uint amount) external onlyOwner {
        feesToken.approve(spender, amount);
    }


    //// Pools Management ////

    function addPool(address poolAddress) external onlyOwner {
        if (enabledPools[poolAddress] == false) {
            enabledPools[poolAddress] = true;
            poolsArray.push(poolAddress);
            poolLPTokensArray.push(address(IPoolV2(poolAddress).lpToken()));
        }
    }


    function removePool(address poolAddress) external onlyOwner {
        if (enabledPools[poolAddress] == true) {
            enabledPools[poolAddress] = false;
        }
    }


    function setFeesPerc(address poolAddress, uint feesPerc) external onlyOwner {
        IPoolV2(poolAddress).setFeesPerc(feesPerc);
    }


    function setSlippageThereshold(address poolAddress, uint slippage) external onlyOwner {
        IPoolV2(poolAddress).setSlippageThereshold(slippage);
    }


    function setSlippageThereshold(address poolAddress, address strategyAddress) external onlyOwner {
        IPoolV2(poolAddress).setStrategy(strategyAddress);
    }


    function setUpkeepInterval(address poolAddress, uint upkeepInterval) external onlyOwner {
        IPoolV2(poolAddress).setUpkeepInterval(upkeepInterval);
    }

}
