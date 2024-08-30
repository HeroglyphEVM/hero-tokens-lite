// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "test/base/BaseTest.t.sol";

import { BaseHeroERC20 } from "src/erc20/BaseHeroERC20.sol";
import { IHeroERC20 } from "src/interfaces/IHeroERC20.sol";

contract BaseHeroERC20Test is BaseTest {
  uint256 private constant MAX_SUPPLY = 1_099_245e18;
  uint256 private constant PRE_MINT_AMOUNT = 99_211e18;

  address private preMintReceiver;
  address private owner;
  address private heroglyph;
  address private feePayer;
  address private validator;

  IHeroERC20.TokenSettings private TOKEN_SETTINGS;
  IHeroERC20.TickerOperatorSettings private TICKER_SETTINGS;

  BaseHeroERC20Harness private underTest;

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

    underTest = new BaseHeroERC20Harness(TOKEN_SETTINGS, TICKER_SETTINGS);
  }

  function generateVariables() internal {
    owner = generateAddress("Owner");
    validator = generateAddress("Validator");
    feePayer = generateAddress("FeePayer");
    heroglyph = generateAddress("HeroGlyphRelay");
    preMintReceiver = generateAddress("PreMint Receiver");
  }

  function test_constructor_whenNoPremit_thenSetups() external {
    TOKEN_SETTINGS.preMintAmount = 0;
    underTest = new BaseHeroERC20Harness(TOKEN_SETTINGS, TICKER_SETTINGS);

    assertEq(underTest.totalSupply(), 0);
    assertEq(underTest.balanceOf(preMintReceiver), 0);
  }

  function test_constructor_withPermit_thenSetups() external {
    underTest = new BaseHeroERC20Harness(TOKEN_SETTINGS, TICKER_SETTINGS);

    assertEq(underTest.totalSupply(), TOKEN_SETTINGS.preMintAmount);
    assertEq(underTest.balanceOf(preMintReceiver), TOKEN_SETTINGS.preMintAmount);
  }

  function test_constructor_thenSetupContract() external view {
    //ERC20 & Capped
    assertEq(underTest.name(), TOKEN_SETTINGS.name);
    assertEq(underTest.symbol(), TOKEN_SETTINGS.symbol);
    assertEq(underTest.cap(), TOKEN_SETTINGS.maxSupply);

    //Ticker Operator
    assertEq(underTest.owner(), owner);
    assertEq(underTest.getFeePayer(), feePayer);
    assertEq(address(underTest.heroglyphRelay()), heroglyph);

    //Premint
    assertEq(underTest.totalSupply(), TOKEN_SETTINGS.preMintAmount);
    assertEq(underTest.balanceOf(preMintReceiver), TOKEN_SETTINGS.preMintAmount);
  }
}

contract BaseHeroERC20Harness is BaseHeroERC20 {
  constructor(
    TokenSettings memory _erc20Settings,
    TickerOperatorSettings memory _tickerOperatorSettings
  ) BaseHeroERC20(_erc20Settings, _tickerOperatorSettings) { }

  function onValidatorTriggered(
    uint32, /*_lzEndpointSelected*/
    uint32, /*_blockNumber*/
    address, /*_identityReceiver*/
    uint128 /*_heroglyphFee*/
  ) external override { }
}
