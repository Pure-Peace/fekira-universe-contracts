/* eslint-disable @typescript-eslint/no-unused-vars */
import {BigNumber, BigNumberish} from 'ethers';

// eslint-disable-next-line @typescript-eslint/ban-types
export type DeployConfig = {
  name: string;
  symbol: string;
  baseURI: string;
  randomnessRevealer: string;
  hashOfLaunchMetadataList: string;
};

const toTokenAmount = (amount: BigNumberish, tokenDecimal: BigNumberish) => {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(tokenDecimal));
};

const config: {[key: string]: DeployConfig} = {
  hardhat: {
    name: 'FekiraUniverse',
    symbol: 'FU',
    baseURI: 'https://p4010183-u833-067a4df9.app.run.fish/api/v1/unpack/',
    randomnessRevealer: '0x86DB88892459F98e3D4337B75aABd7E3D2734328',
    hashOfLaunchMetadataList:
      '0x03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
  },
  kovan: {
    name: 'FekiraUniverse-Test',
    symbol: 'FU',
    baseURI: 'https://p4010183-u833-067a4df9.app.run.fish/api/v1/unpack/',
    randomnessRevealer: '0x86DB88892459F98e3D4337B75aABd7E3D2734328',
    hashOfLaunchMetadataList:
      '0x03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
  },
  mainnet: {
    name: 'FekiraUniverse',
    symbol: 'FU',
    baseURI: 'https://p4010183-u833-067a4df9.app.run.fish/api/v1/unpack/',
    randomnessRevealer: '0x86DB88892459F98e3D4337B75aABd7E3D2734328',
    hashOfLaunchMetadataList:
      '0x03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
  },
  rinkeby: {
    name: 'FekiraUniverse-Test',
    symbol: 'FU',
    baseURI: 'https://p4010183-u833-067a4df9.app.run.fish/api/v1/unpack/',
    randomnessRevealer: '0x86DB88892459F98e3D4337B75aABd7E3D2734328',
    hashOfLaunchMetadataList:
      '0x03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
  },
};

export default config;
