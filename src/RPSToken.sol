// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./ERC20.sol";

contract RPSToken {
    ERC20 erc20Contract;

    uint256 public supplyLimit;
    address owner;

    constructor() {
        erc20Contract = new ERC20();
        supplyLimit = 10000;
        owner = msg.sender;
    }

    function currentSupply() public view returns(uint256) {
        return erc20Contract.totalSupply();
    }

    function balanceOf(address account) public view returns(uint256) {
        return erc20Contract.balanceOf(account);
    }

    function topUp() public payable {
        require(msg.value > 0.01 ether, "at least 0.01 ETH is needed to join the game");
        require(erc20Contract.totalSupply() + msg.value / (5 * 10**17) < supplyLimit, "RPST supply is not enough");
        erc20Contract.mint(msg.sender, msg.value / (5 * 10**17));
    }

    function transfer(address _to, uint256 _value) public {
        erc20Contract.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 value) public {
        erc20Contract.transferFrom(_from, _to, value);
    }

    function approve(address _owner, address _spender, uint256 _value) public returns (bool) {
        return erc20Contract.DTapprove(_owner, _spender, _value);
    }

    function checkAllowance(address _owner, address _spender) public view returns (uint256) {
        return erc20Contract.allowance(_owner, _spender);
    }

    function stopMinting() public returns (bool) {
        return erc20Contract.finishMinting();
    }

}