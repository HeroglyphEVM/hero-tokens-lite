// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IHeroERC20 {
  struct TokenSettings {
    string name;
    string symbol;
    uint256 maxSupply;
    uint256 preMintAmount;
    address preMintTo;
  }

  struct TickerOperatorSettings {
    address owner;
    address heroglyphRelay;
    address feePayer;
  }
}
