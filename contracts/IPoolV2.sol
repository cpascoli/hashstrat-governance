// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPoolV2 {

    function lpToken() external view returns (IERC20Metadata);
    function totalPortfolioValue() external view returns(uint);
    function investedTokenValue() external view returns(uint);
    function depositTokenValue() external view returns(uint);
    function portfolioValue(address _addr) external view returns (uint);

    function setFeesPerc(uint _feesPerc) external;
    function withdrawFees(uint amount) external;
    function setSlippageThereshold(uint slippage) external;
    function setStrategy(address strategyAddress) external;
    function setUpkeepInterval(uint upkeepInterval) external;
    
}