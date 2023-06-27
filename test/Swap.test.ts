import { BigNumber } from "@ethersproject/bignumber";
import { parseUnits } from "@ethersproject/units";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { getAddress as getAddressLib } from "@zetachain/addresses";
import { expect } from "chai";
import { ethers, network } from "hardhat";

import { getSwapParams } from "./helpers";
import {
  TestSystemContract,
  TestZRC20,
  ZetaSwapV2,
  ZetaSwapV2__factory,
} from "../typechain-types";
import { evmSetup } from "./test.helpers";

describe("ZetaSwap tests", () => {
  let zetaSwapV2Contract: ZetaSwapV2;
  let ZRC20Contracts: TestZRC20[];
  let systemContract: TestSystemContract;

  let accounts: SignerWithAddress[];
  let deployer: SignerWithAddress;

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    [deployer] = accounts;

    await network.provider.send("hardhat_setBalance", [
      deployer.address,
      parseUnits("1000000").toHexString(),
    ]);

    const uniswapRouterAddr = getAddressLib({
      address: "uniswapV2Router02",
      networkName: "eth-mainnet",
      zetaNetwork: "mainnet",
    });

    const uniswapFactoryAddr = getAddressLib({
      address: "uniswapV2Factory",
      networkName: "eth-mainnet",
      zetaNetwork: "mainnet",
    });

    const wGasToken = getAddressLib({
      address: "weth9",
      networkName: "eth-mainnet",
      zetaNetwork: "mainnet",
    });

    const evmSetupResult = await evmSetup(
      wGasToken,
      uniswapFactoryAddr,
      uniswapRouterAddr
    );
    ZRC20Contracts = evmSetupResult.ZRC20Contracts;
    systemContract = evmSetupResult.systemContract;

    const FactorySwapV2 = (await ethers.getContractFactory(
      "ZetaSwapV2"
    )) as ZetaSwapV2__factory;
    zetaSwapV2Contract = (await FactorySwapV2.deploy(
      systemContract.address
    )) as ZetaSwapV2;
    await zetaSwapV2Contract.deployed();
  });

  describe("zetaSwapV2", () => {
    it("Should do swap", async () => {
      const amount = parseUnits("10");
      await ZRC20Contracts[0].transfer(zetaSwapV2Contract.address, amount);
      const initBalance = await ZRC20Contracts[1].balanceOf(deployer.address);

      const params = getSwapParams(
        deployer.address,
        ZRC20Contracts[1].address,
        BigNumber.from(0)
      );

      await zetaSwapV2Contract.onCrossChainCall(
        ZRC20Contracts[0].address,
        amount,
        params
      );

      const endBalance = await ZRC20Contracts[1].balanceOf(deployer.address);
      expect(endBalance).to.be.gt(initBalance);
    });
  });
});