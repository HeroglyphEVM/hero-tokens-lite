// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseHeroERC20 } from "../BaseHeroERC20.sol";

/**
 * @title HeroERC20Fixed
 * @author 0xAtum (https://x.com/0xAtum)
 * @notice ERC20 that rewards a fixed amount for each valid block, with an additional
 * bonus (optional) if the token has not been emitted for a certain period.
 * @dev We use uint32 for the block number since we are tracking Ethereum blocks. It is
 * estimated that this will overflow in the year 3663.
 * @dev We also use uint32 for the timestamp, which will overflow in approximately 81
 * years.
 */
contract HeroERC20Fixed is BaseHeroERC20 {
  uint256 public immutable rewardPerBlock;
  uint256 public immutable maxBonusRewardAfterOneDay;

  uint32 public lastEthereumMintedBlock;
  uint32 public lastUnixTimeRewarded;

  constructor(
    uint256 _rewardPerBlock,
    uint256 _maxBonusRewardAfterOneDay,
    TokenSettings memory _erc20Settings,
    TickerOperatorSettings memory _tickerOperatorSettings
  ) BaseHeroERC20(_erc20Settings, _tickerOperatorSettings) {
    rewardPerBlock = _rewardPerBlock;
    maxBonusRewardAfterOneDay = _maxBonusRewardAfterOneDay;
    lastUnixTimeRewarded = uint32(block.timestamp);
  }

  function onValidatorTriggered(
    uint32, /*_lzEndpointSelected*/
    uint32 _blockNumber,
    address _identityReceiver,
    uint128 _heroglyphFee
  ) external override onlyRelay {
    // Repay Heroglyph for the executed code. As of now, the fee is zero, but if it's
    // become non-zero, we need to repay it. We keep the function call to ensure
    // compatibility with future changes.
    _repayHeroglyph(_heroglyphFee);
    uint256 rewardToMind = _calculateTokensToEmit(uint32(block.timestamp));

    // Using `return` instead of `revert` to optimize gas usage on Heroglyph Protocol.
    if (_blockNumber <= lastEthereumMintedBlock) return;
    if (rewardToMind == 0) return;

    lastEthereumMintedBlock = _blockNumber;
    lastUnixTimeRewarded = uint32(block.timestamp);

    _mint(_identityReceiver, rewardToMind);
  }

  function getPendingReward() external view returns (uint256) {
    return _calculateTokensToEmit(uint32(block.timestamp));
  }

  function _calculateTokensToEmit(uint32 _timestamp)
    internal
    view
    returns (uint256 rewardToMint_)
  {
    uint256 bonus = 0;

    if (_timestamp > lastUnixTimeRewarded) {
      uint256 timePassed = (_timestamp - lastUnixTimeRewarded);
      bonus = timePassed * maxBonusRewardAfterOneDay / 1 days;

      if (bonus > maxBonusRewardAfterOneDay) {
        bonus = maxBonusRewardAfterOneDay;
      }
    }

    rewardToMint_ = rewardPerBlock + bonus;

    if (totalSupply() + rewardToMint_ > cap()) {
      rewardToMint_ = cap() - totalSupply();
    }

    return rewardToMint_;
  }
}
