/* eslint-disable prettier/prettier */
import "@nomicfoundation/hardhat-toolbox";
import "./tasks/account";
import "./tasks/verify";
import "./tasks/balances";
import "./tasks/faucet";
import "./tasks/deploy";
import "./tasks/withdraw";
import "./tasks/mint";
import "./tasks/transfer";

import { getHardhatConfigNetworks } from "@zetachain/addresses-tools/dist/networks";
import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";

dotenv.config();
const PRIVATE_KEYS =
  process.env.PRIVATE_KEY !== undefined ? [`0x${process.env.PRIVATE_KEY}`] : [];

const config: HardhatUserConfig = {
  etherscan: {
    // apiKey: {
    //   bscTestnet: `${process.env.BSCSCAN_API}`,
    // },

    apiKey: process.env.ETHERSCAN_API, // ethereum
    // apiKey: process.env.POLYGONSCAN_API, // polygon
  },
  networks: {
    ...getHardhatConfigNetworks(PRIVATE_KEYS),
    bscTestnet: {
      chainId: 97,
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
    },
    goerli: {
      accounts: [`${process.env.PRIVATE_KEY}`],
      url: process.env.ALCHEMY_GOERLI,
    },
  },
  solidity: {
    compilers: [
      { version: "0.6.6" /** For uniswap v2 */ },
      { version: "0.8.7" },
    ],
  },
};

export default config;
