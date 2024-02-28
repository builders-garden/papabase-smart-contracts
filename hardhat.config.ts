import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter"
require("dotenv").config();

/*
const config: HardhatUserConfig = {
  solidity: "0.8.24",
};
*/

module.exports = {
  solidity: "0.8.24",
  networks: {
    hardhat: {
      forking: {
        url: process.env.BASE_RPC_URL,
      },
      chainId: 8453,
    },
  },
};

export default module.exports;
