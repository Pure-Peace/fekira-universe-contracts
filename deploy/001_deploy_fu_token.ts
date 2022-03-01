import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {genGetContractWith} from '../test/utils/genHelpers';
import {FekiraUniverse} from '../typechain/FekiraUniverse';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer} = await getNamedAccounts();

  const fuTokenDeployments = await deploy('FekiraUniverse', {
    from: deployer,
    contract: 'FekiraUniverse',
    args: ['FekiraUniverse', 'FU', deployer, '0x0'],
    log: true,
    skipIfAlreadyDeployed: false,
    gasLimit: 5500000,
  });
  const {getContractAt} = genGetContractWith(hre);
  const fuToken = await getContractAt<FekiraUniverse>(
    'FekiraUniverse',
    fuTokenDeployments.address,
    deployer
  );
};
export default func;
func.id = 'deploy_fu_token';
func.tags = ['FekiraUniverse'];
