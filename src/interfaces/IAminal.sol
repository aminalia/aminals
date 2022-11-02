pragma solidity ^0.8.16;

interface IAminal {
  
    function mint(address to, uint256 quantity) external payable returns (uint256 fromTokenId);
}