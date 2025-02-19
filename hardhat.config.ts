import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from 'dotenv'; 
dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    calibration: {
      url: process.env.CALIBRATION_TESTNET_RPC_URL,
      accounts: [`${process.env.CALIBRATION_TESTNET_PRIVATE_KEY}`]
    }
  }
};

export default config;
