// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IHeroERC20 } from "../interfaces/IHeroERC20.sol";

import {
  ERC20,
  ERC20Capped
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import { TickerOperator } from "heroglyph-library/TickerOperator.sol";

abstract contract BaseHeroERC20 is IHeroERC20, ERC20Capped, TickerOperator {
  constructor(
    TokenSettings memory _erc20Settings,
    TickerOperatorSettings memory _tickerOperatorSettings
  )
    ERC20(_erc20Settings.name, _erc20Settings.symbol)
    ERC20Capped(_erc20Settings.maxSupply)
    TickerOperator(
      _tickerOperatorSettings.owner,
      _tickerOperatorSettings.heroglyphRelay,
      _tickerOperatorSettings.feePayer
    )
  {
    uint256 preMint = _erc20Settings.preMintAmount;
    if (preMint == 0) return;

    _mint(_erc20Settings.preMintTo, _erc20Settings.preMintAmount);
  }

  /**
   * @notice onValidatorTriggered() Callback function when your ticker has been selected
   * @param _lzEndpointSelected // The selected layer zero endpoint target for this ticker
   * @param _blockNumber  // The number of the block minted
   * @param _identityReceiver // The Identity's receiver from the miner graffiti
   * @param _heroglyphFee // The fee to pay for the execution
   * @dev be sure to apply onlyRelay to this function
   * @dev TIP: Avoid using reverts; instead, use return statements, unless you need to
   * restore your contract to its
   * initial state.
   * @dev TIP:Keep in mind that a miner may utilize your ticker more than once in their
   * graffiti. To avoid any
   * repetition, consider utilizing blockNumber to track actions.
   */
  function onValidatorTriggered(
    uint32 _lzEndpointSelected,
    uint32 _blockNumber,
    address _identityReceiver,
    uint128 _heroglyphFee
  ) external virtual override;
}
