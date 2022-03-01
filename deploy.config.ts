/* eslint-disable @typescript-eslint/no-unused-vars */
import {BigNumber, BigNumberish} from 'ethers';

// eslint-disable-next-line @typescript-eslint/ban-types
export type DeployConfig = {
  name: string;
  symbol: string;
  randomnessRevealer: string;
  hashOfLaunchMetadataList: string;
};

const toTokenAmount = (amount: BigNumberish, tokenDecimal: BigNumberish) => {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(tokenDecimal));
};

const config: {[key: string]: DeployConfig} = {
  kovan: {
    name: 'FekiraUniverse',
    symbol: 'FU',
    randomnessRevealer: 'address',
    hashOfLaunchMetadataList: '0x0',
  },
  mainnet: {
    name: 'FekiraUniverse',
    symbol: 'FU',
    randomnessRevealer: 'address',
    hashOfLaunchMetadataList: '0x0',
  },
};

export default config;
