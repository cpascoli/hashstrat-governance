// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * The token of the HashStrat DAO
 * 
 * HashStrat DAO tokens has fixed supply which is all devolved to the Staking Pool to reward 
 * providers of liquidity to HashStrat Pools and Indexex.
 *
 * Users that provide liquidity into HashStrat Pools and Indexex and stake their LP tokens
 * will earn HashStrat DAO tokens that allow to partecipate in the DAO governance and revenue share programs.
 * 
 */

contract HashStratDAOToken is ERC20 {

    uint8 immutable decs;

    bool public tokensMinted = false;

    constructor (string memory _name, string memory _symbol, uint8 _decimals, uint supply) ERC20(_name, _symbol) {
        decs = _decimals;
        _mint(address(msg.sender), supply);
    }

    function decimals() public view override returns (uint8) {
        return decs;
    }
}
