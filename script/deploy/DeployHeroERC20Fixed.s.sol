// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BaseScript.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { HeroERC20Fixed } from "src/erc20/distributions/HeroERC20Fixed.sol";
import { IHeroERC20 } from "src/interfaces/IHeroERC20.sol";

struct TokenConfig {
  string name;
  string symbol;
  uint256 maxSupply;
  uint256 preMintAmount;
  uint256 rewardPerBlock;
  uint256 maxBonusFullDay;
}

struct GeneralConfig {
  address owner;
  address preMintReceiver;
  address heroglyphRelay;
  address feePayer;
}

contract DeployTokensScript is BaseScript {
  string private constant CONFIG_NAME = "GeneralConfig";
  string private constant TOKEN_CONFIGS_NAME = "TokenSettings";

  GeneralConfig generalConfig;
  uint256 activeDeployer;
  address deployerWallet;

  function run() external {
    activeDeployer = _getDeployerPrivateKey();
    deployerWallet = _getDeployerAddress();

    generalConfig = abi.decode(
      vm.parseJson(_getConfig(CONFIG_NAME), string.concat(".", _getNetwork())),
      (GeneralConfig)
    );

    TokenConfig[] memory tokens =
      abi.decode(vm.parseJson(_getConfig(TOKEN_CONFIGS_NAME)), (TokenConfig[]));

    _loadContracts();

    if (tokens.length == 0) revert("NO TOKENS");

    IHeroERC20.TickerOperatorSettings memory tickerSettings = IHeroERC20
      .TickerOperatorSettings({
      owner: generalConfig.owner,
      heroglyphRelay: generalConfig.heroglyphRelay,
      feePayer: generalConfig.feePayer
    });

    TokenConfig memory token;
    address tokenContractAddr;
    bool alreadyExisting;
    bytes memory args;

    for (uint256 i = 0; i < tokens.length; ++i) {
      token = tokens[i];
      token.maxSupply = token.maxSupply;

      args = abi.encode(
        token.rewardPerBlock,
        token.maxBonusFullDay,
        IHeroERC20.TokenSettings({
          name: token.name,
          symbol: token.symbol,
          maxSupply: token.maxSupply,
          preMintAmount: token.preMintAmount,
          preMintTo: generalConfig.preMintReceiver
        }),
        tickerSettings
      );

      (tokenContractAddr, alreadyExisting) = _tryDeployContract(
        string.concat("Token_", token.name), 0, type(HeroERC20Fixed).creationCode, args
      );
    }
  }
}
