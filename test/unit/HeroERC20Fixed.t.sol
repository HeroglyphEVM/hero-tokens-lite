// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "test/base/BaseTest.t.sol";

import { HeroERC20Fixed } from "src/erc20/distributions/HeroERC20Fixed.sol";

import { IHeroERC20 } from "src/interfaces/IHeroERC20.sol";
import { ITickerOperator } from "heroglyph-library/ITickerOperator.sol";

contract HeroERC20FixedTest is BaseTest {
  uint256 private constant MAX_SUPPLY = 1_099_245e18;
  uint256 private constant PRE_MINT_AMOUNT = 99_211e18;
  uint256 private constant REWARD_PER_BLOCK = 5.45e18;
  uint256 private constant MAX_BONUS_FULL_DAY = 11.33e18;

  address private preMintReceiver;
  address private owner;
  address private heroglyph;
  address private feePayer;
  address private validator;

  IHeroERC20.TokenSettings private TOKEN_SETTINGS;
  IHeroERC20.TickerOperatorSettings private TICKER_SETTINGS;

  HeroERC20FixedHarness private underTest;

  function setUp() external {
    skip(1_832_719);
    generateVariables();

    TOKEN_SETTINGS = IHeroERC20.TokenSettings({
      name: "TokenTest",
      symbol: "TT",
      maxSupply: MAX_SUPPLY,
      preMintAmount: PRE_MINT_AMOUNT,
      preMintTo: preMintReceiver
    });

    TICKER_SETTINGS = IHeroERC20.TickerOperatorSettings({
      owner: owner,
      heroglyphRelay: heroglyph,
      feePayer: feePayer
    });

    underTest = new HeroERC20FixedHarness(
      REWARD_PER_BLOCK, MAX_BONUS_FULL_DAY, TOKEN_SETTINGS, TICKER_SETTINGS
    );
  }

  function generateVariables() internal {
    owner = generateAddress("Owner");
    validator = generateAddress("Validator");
    feePayer = generateAddress("FeePayer");
    heroglyph = generateAddress("HeroGlyphRelay");
    preMintReceiver = generateAddress("PreMint Receiver");
  }

  function test_constructor_thenSetupContract() external {
    underTest = new HeroERC20FixedHarness(
      REWARD_PER_BLOCK, MAX_BONUS_FULL_DAY, TOKEN_SETTINGS, TICKER_SETTINGS
    );

    assertEq(underTest.lastEthereumMintedBlock(), 0);
    assertEq(underTest.rewardPerBlock(), REWARD_PER_BLOCK);
    assertEq(underTest.maxBonusRewardAfterOneDay(), MAX_BONUS_FULL_DAY);
    assertEq(underTest.lastUnixTimeRewarded(), block.timestamp);
  }

  function test_onValidatorTiggered_whenNotHeroglyph_thenReverts() external {
    vm.expectRevert(ITickerOperator.NotHeroglyph.selector);
    underTest.onValidatorTriggered(0, 300, validator, 0);
  }

  function test_onValidatorTriggered_whenBlockNumberIsNotHigherThanLastOne_thenDoNothing()
    external
    prankAs(heroglyph)
  {
    uint32 blockNumber = 3382;
    uint32 unixTime = 0;
    unixTime += uint32(block.timestamp);

    underTest.onValidatorTriggered(0, blockNumber, validator, 0);
    uint256 validatorBalance = underTest.balanceOf(validator);

    skip(30 days);
    underTest.onValidatorTriggered(0, blockNumber, validator, 0);

    assertEq(underTest.balanceOf(validator), validatorBalance);
    assertEq(underTest.lastEthereumMintedBlock(), blockNumber);
    assertEq(underTest.lastUnixTimeRewarded(), unixTime);
  }

  function test_onValidatorTrigerred_whenNoReward_thenDoNothing()
    external
    prankAs(heroglyph)
  {
    TOKEN_SETTINGS.preMintAmount = MAX_SUPPLY - REWARD_PER_BLOCK;
    underTest = new HeroERC20FixedHarness(
      REWARD_PER_BLOCK, MAX_BONUS_FULL_DAY, TOKEN_SETTINGS, TICKER_SETTINGS
    );

    uint32 blockNumber = 3382;
    uint32 unixTime = 0;
    unixTime += uint32(block.timestamp);

    underTest.onValidatorTriggered(0, blockNumber, validator, 0);
    uint256 validatorBalance = underTest.balanceOf(validator);

    assertEq(underTest.totalSupply(), underTest.cap());

    skip(30 days);
    underTest.onValidatorTriggered(0, blockNumber + 1, validator, 0);

    assertEq(underTest.balanceOf(validator), validatorBalance);
    assertEq(underTest.lastEthereumMintedBlock(), blockNumber);
    assertEq(underTest.lastUnixTimeRewarded(), unixTime);
  }

  function test_onValidatorTrigerred_whenNoTimePassedSinceLast_thenRewardsValidatorWithoutBonus(
  ) external prankAs(heroglyph) {
    uint32 blockNumber = 99_282;

    underTest.onValidatorTriggered(0, blockNumber, validator, 0);

    assertEq(underTest.lastEthereumMintedBlock(), blockNumber);
    assertEq(underTest.lastUnixTimeRewarded(), block.timestamp);
    assertEq(underTest.balanceOf(validator), REWARD_PER_BLOCK);
  }

  function test_onValidatorTrigerred_whenTimePassedSinceLast_thenRewardsValidatorWithBonus(
  ) external prankAs(heroglyph) {
    uint32 blockNumber = 99_282;

    skip(1 days / 3);

    uint256 bonusRate = MAX_BONUS_FULL_DAY / 1 days;
    uint256 timePassed = (block.timestamp - underTest.lastUnixTimeRewarded());
    uint256 expectedReward = REWARD_PER_BLOCK + (timePassed * bonusRate);

    underTest.onValidatorTriggered(0, blockNumber, validator, 0);

    assertEq(underTest.lastEthereumMintedBlock(), blockNumber);
    assertEq(underTest.lastUnixTimeRewarded(), block.timestamp);
    assertEq(underTest.balanceOf(validator), expectedReward);
  }

  function test_getPendingReward_thenReturnsResult() external {
    assertEq(underTest.getPendingReward(), REWARD_PER_BLOCK);

    skip(1 days - 3000);

    uint256 bonusRate = MAX_BONUS_FULL_DAY / 1 days;
    uint256 timePassed = (block.timestamp - underTest.lastUnixTimeRewarded());
    uint256 expectedReward = REWARD_PER_BLOCK + (timePassed * bonusRate);

    assertEq(underTest.getPendingReward(), expectedReward);

    skip(3010);
    assertEq(underTest.getPendingReward(), REWARD_PER_BLOCK + MAX_BONUS_FULL_DAY);

    expectedReward = 0.302e18;
    underTest.exposed_mint(
      validator, underTest.cap() - (underTest.totalSupply() + expectedReward)
    );
    assertEq(underTest.getPendingReward(), expectedReward);
  }
}

contract HeroERC20FixedHarness is HeroERC20Fixed {
  constructor(
    uint256 _rewardPerBlock,
    uint256 _maxBonusRewardAfterOneDay,
    TokenSettings memory _erc20Settings,
    TickerOperatorSettings memory _tickerOperatorSettings
  )
    HeroERC20Fixed(
      _rewardPerBlock,
      _maxBonusRewardAfterOneDay,
      _erc20Settings,
      _tickerOperatorSettings
    )
  { }

  function exposed_mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }
}
