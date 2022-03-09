/* eslint-disable @typescript-eslint/explicit-module-boundary-types */
/* eslint-disable @typescript-eslint/no-var-requires */
import hre from 'hardhat';
import {ContractTransaction} from 'ethers';
import {DeployResult} from 'hardhat-deploy/types';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';

import NETWORK_DEPLOY_CONFIG, {DeployConfig} from '../deploy.config';

export const GAS_LIMIT = 5500000;

require('dotenv').config();

const {deploy: _dep} = hre.deployments;

let __DEPLOY_CONFIG: DeployConfig;
export function deployConfig() {
  if (__DEPLOY_CONFIG) return __DEPLOY_CONFIG;
  __DEPLOY_CONFIG = NETWORK_DEPLOY_CONFIG[hre.network.name];
  if (!__DEPLOY_CONFIG) {
    throw new Error(`Unconfigured network: "${hre.network.name}"`);
  }
  return __DEPLOY_CONFIG;
}

export type DeployFunction = (
  deployName: string,
  contractName: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  args?: string[] | any[]
) => Promise<DeployResult>;
export type Deployments = {[key: string]: DeployResult};

export async function setup(): Promise<{
  accounts: SignerWithAddress[];
  deployer: SignerWithAddress;
  deploy: (
    deployName: string,
    contractName: string,
    args?: string[]
  ) => Promise<DeployResult>;
}> {
  const accounts = await hre.ethers.getSigners();
  const deployer = accounts[0];
  console.log('Network:', hre.network.name);
  console.log('Signer:', deployer.address);
  console.log(
    'Signer balance:',
    hre.ethers.utils.formatEther(await deployer.getBalance()).toString(),
    'ETH'
  );

  return {
    accounts,
    deployer,
    deploy: async (
      deployName: string,
      contractName: string,
      args: string[] = []
    ): Promise<DeployResult> => {
      console.log(
        `\n>> Deploying contract "${deployName}" ("${contractName}")...`
      );
      const deployResult = await _dep(deployName, {
        contract: contractName,
        args: args,
        log: true,
        skipIfAlreadyDeployed: false,
        gasLimit: GAS_LIMIT,
        from: deployer.address,
      });
      console.log(
        `${
          deployResult.newlyDeployed ? '[New]' : '[Reused]'
        } contract "${deployName}" ("${contractName}") deployed at "${
          deployResult.address
        }" \n - tx: "${deployResult.transactionHash}" \n - gas: ${
          deployResult.receipt?.gasUsed
        } \n - deployer: "${deployer.address}"`
      );
      return deployResult;
    },
  };
}

export function waitContractCall(
  transcation: ContractTransaction
): Promise<void> {
  return new Promise<void>((resolve) => {
    transcation.wait().then((receipt) => {
      console.log(
        `Waiting transcation: "${receipt.transactionHash}" (block: ${receipt.blockNumber} gasUsed: ${receipt.gasUsed})`
      );
      if (receipt.status === 1) {
        return resolve();
      }
    });
  });
}

export async function deployContracts(deploy: DeployFunction) {
  console.log('\n>>>>>>>>> Deploying contracts...\n');
  const {
    name,
    symbol,
    baseURI,
    randomnessRevealer,
    hashOfLaunchMetadataList,
  } = deployConfig();
  return await deploy('FekiraUniverse', 'FekiraUniverse', [
    name,
    symbol,
    baseURI,
    randomnessRevealer,
    hashOfLaunchMetadataList,
  ]);
}

export async function deployFekiraUniverse() {
  const {deployer, deploy} = await setup();
  const deployments = await deployContracts(deploy);
  console.log('>>> CONTRACTS SETUP DONE <<<');
}
