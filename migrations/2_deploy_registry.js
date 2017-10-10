const namehash = require('eth-ens-namehash').hash

const AbstractENS = artifacts.require('AbstractENS')
const RepoRegistry = artifacts.require('RepoRegistry')
const Repo = artifacts.require('Repo')
const ForwarderFactory = artifacts.require('ForwarderFactory')

const ensAddrs = {
    ropsten: '0x112234455C3a32FD11230C42E7Bccd4A84e02010'
}

const rootNode = namehash('aragonpm.test')
// if registry was previously deployed, setting address here will claim ENS name
const oldRegistryAddr = '0xaa4190514ce13c9848e70e0d26575adb82adada4'

module.exports = (deployer, network, accounts) => {
    console.log('deploying registry on network', network)
    const ens = AbstractENS.at(ensAddrs[network])

    return deployer
        .then(() => Repo.new())
        .then(masterRepo => {
            // replace beefbeef... placeholder in contract binary for actual repo address
            const repoPlaceholder = 'beefbeefbeefbeefbeefbeefbeefbeefbeefbeef'
            const repoAddr = masterRepo.address.slice(2)
            const factoryInitcode = ForwarderFactory.binary.replace(repoPlaceholder, repoAddr)
            return ForwarderFactory.new({ data: factoryInitcode })
        })
        .then(repoFactory => RepoRegistry.new(ens.address, rootNode, repoFactory.address))
        .then(registry => {
            console.log('Deployed registry at', registry.address)
            if (!oldRegistryAddr) {
                console.log('Transfering name ownership')
                return ens.setOwner(rootNode, registry.address)
            } else {
                console.log('Requesting name ownership from old registry')
                return RepoRegistry.at(oldRegistryAddr).setRootOwner(registry.address)
            }
        })
}
