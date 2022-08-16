import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";

require('dotenv').config()


const { RPC_URL_POLYGON_MAIN, RPC_URL_KOVAN, OWNER_PRIVATE_KEY, ETHERSCAN_API_KEY, POLYGONSCAN_API_KEY, MNEMONIC} = process.env;

const config: HardhatUserConfig = {
  solidity: "0.8.15",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: RPC_URL_POLYGON_MAIN || "",
        blockNumber: 31843770 //31481928
      }
    },
    kovan: {
      url: RPC_URL_KOVAN,
      accounts: { mnemonic: MNEMONIC  },
      // gasPrice:  400000000000, // 100 Gwei
    },
    polygon: {
      url: RPC_URL_POLYGON_MAIN,
      accounts: { mnemonic: MNEMONIC  },
      gasPrice:  50000000000,  // 70 Gwei
    },
  },
  etherscan: {
    apiKey: {
        mainnet: ETHERSCAN_API_KEY || "",
        kovan: ETHERSCAN_API_KEY || "",
        polygon: POLYGONSCAN_API_KEY || "",
    }
  },
};

export default config;
